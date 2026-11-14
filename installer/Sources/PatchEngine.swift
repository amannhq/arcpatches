// Patches a browser (Dia by default; see Browsers.swift) with arcpatches.dylib, shipped
// inside ArcPatches.app, so no compiler is needed.
//
// Two modes:
//  - In place (default): /Applications/Dia.app itself becomes "Dia Arc". An untouched
//    copy of the original is kept as a backup (an APFS clone, so it takes no space),
//    Dia's own updater stays on, and after it installs an update ArcPatches re-patches.
//  - Copy: a separate ~/Applications/Dia Arc.app; the regular Dia stays stock.
// The statics below describe the selected browser. Each job reads it once and works
// on that copy, so changing the selection mid-patch can't mix two browsers' paths.
import AppKit

enum PatchMode: String { case inPlace, copy }

enum PatchError: LocalizedError {
    case diaMissing(String), patchedRunning(String), busy, noBackup(String), permission(String), step(String)
    var errorDescription: String? {
        switch self {
        case .diaMissing(let n): return "\(n) isn't installed in /Applications."
        case .patchedRunning(let n): return "Quit \(n) first."
        case .busy: return "Already patching."
        case .noBackup(let n): return "The original \(n) backup is missing. Reinstall \(n), then patch again."
        case .permission(let n): return "macOS blocked ArcPatches from changing \(n). Allow ArcPatches in System Settings › Privacy & Security › App Management, then try again."
        case .step(let s): return s
        }
    }
}

struct PatchStatus {
    enum State { case upToDate, needsPatch(String), notInstalled, diaMissing, restored, checking }
    var state: State
    var diaVersion: String?     // the installed browser's version (named for Dia, the first browser)
    var patchedFrom: String?
}

extension PatchStatus {
    var isUpToDate: Bool { if case .upToDate = state { return true }; return false }
}

final class PatchEngine: Sendable {
    /// The browser being patched.
    static var browser: BrowserTarget { BrowserTarget.selected }
    static var source: URL { browser.source }
    static var supportDir: URL { browser.supportDir }
    static var backup: URL { browser.backup }
    static var copyDestination: URL { browser.copyDestination }
    /// What the user runs: the browser itself, by its own name, when patched in place.
    static var appName: String { mode == .inPlace ? browser.name : browser.appName }
    static var targetName: String { browser.targetName }
    static var mode: PatchMode { browser.mode }
    static var destination: URL { browser.destination }
    static var restoredByUser: Bool {
        get { browser.restoredByUser }
        set { browser.restoredByUser = newValue }
    }
    static var patchedIsRunning: Bool { browser.patchedIsRunning }
    static var diaIsRunning: Bool { browser.isRunning }

    let dylib: URL
    let entitlements: URL
    let patchVersion: String

    init(resources: URL) {
        dylib = resources.appendingPathComponent("arcpatches.dylib")
        entitlements = resources.appendingPathComponent("entitlements.plist")
        patchVersion = (try? String(contentsOf: resources.appendingPathComponent("VERSION"), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "?"
    }

    static func info(_ app: URL) -> [String: Any]? {
        NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")) as? [String: Any]
    }

    static func version(_ app: URL) -> String? {
        guard let i = info(app) else { return nil }
        return "\(i["CFBundleShortVersionString"] ?? "?") (\(i["CFBundleVersion"] ?? "?"))"
    }

    static func isPatched(_ app: URL) -> Bool { info(app)?["ArcPatchesPatchVersion"] != nil }

    /// `codesign --verify --strict`: catches swapped nested code (e.g. arcpatches.dylib) or a
    /// re-signed bundle. With `requirement`, the signer must also match it.
    static func signatureValid(_ app: URL, requirement: String? = nil) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        p.arguments = ["--verify", "--strict"] + (requirement.map { ["-R", "=" + $0] } ?? []) + [app.path]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    func status() -> PatchStatus {
        let b = Self.browser
        guard let src = Self.info(b.source) else { return PatchStatus(state: .diaMissing) }
        if b.mode == .inPlace {
            if !Self.isPatched(b.source) {
                // Stock browser: never patched, restored by the user, or just updated by its own updater.
                let v = Self.version(b.source)
                if b.restoredByUser { return PatchStatus(state: .restored, diaVersion: v) }
                guard let bk = Self.info(b.backup) else { return PatchStatus(state: .notInstalled, diaVersion: v) }
                let updated = (bk["CFBundleVersion"] as? String) != (src["CFBundleVersion"] as? String)
                return PatchStatus(state: .needsPatch(updated ? "\(b.name) was updated" : "\(b.name) isn't patched"), diaVersion: v)
            }
            var s = PatchStatus(state: .upToDate, diaVersion: Self.version(b.backup) ?? Self.version(b.source), patchedFrom: Self.version(b.source))
            if (src["ArcPatchesPatchVersion"] as? String) != patchVersion { s.state = .needsPatch("New ArcPatches version") }
            else if !FileManager.default.fileExists(atPath: b.backup.path) { s.state = .needsPatch("Original backup missing") }
            else if !Self.signatureValid(b.source) { s.state = .needsPatch("\(b.appName) was modified") }
            return s
        }
        let srcBuild = src["CFBundleVersion"] as? String
        let srcVersion = Self.version(b.source)
        guard let dst = Self.info(b.copyDestination) else {
            return PatchStatus(state: .notInstalled, diaVersion: srcVersion)
        }
        let patchedFrom = dst["ArcPatchesSourceBuild"] as? String
        var s = PatchStatus(state: .upToDate, diaVersion: srcVersion, patchedFrom: Self.version(b.copyDestination))
        if patchedFrom == nil {
            s.state = .needsPatch("Built outside ArcPatches")
        } else if patchedFrom != srcBuild {
            s.state = .needsPatch("\(b.name) was updated")
        } else if (dst["ArcPatchesPatchVersion"] as? String) != patchVersion {
            s.state = .needsPatch("New ArcPatches version")
        } else if !Self.signatureValid(b.copyDestination) {
            s.state = .needsPatch("\(b.appName) was modified")
        }
        return s
    }

    // Compare paths, not URLs: a running app's bundleURL has a trailing slash.
    static func isRunning(_ app: URL) -> Bool {
        let path = app.resolvingSymlinksInPath().path
        return NSWorkspace.shared.runningApplications.contains { $0.bundleURL?.resolvingSymlinksInPath().path == path }
    }

    private func withLock<T>(_ b: BrowserTarget, _ body: () throws -> T) throws -> T {
        let fm = FileManager.default
        try? fm.createDirectory(at: b.supportDir, withIntermediateDirectories: true)
        let lock = open(b.supportDir.appendingPathComponent("patch.lock").path, O_CREAT | O_RDWR, 0o644)
        guard lock >= 0, flock(lock, LOCK_EX | LOCK_NB) == 0 else { if lock >= 0 { close(lock) }; throw PatchError.busy }
        defer { flock(lock, LOCK_UN); close(lock) }
        return try body()
    }

    /// Runs off the main thread; takes ~10 s (APFS clone + signing).
    func patch() throws {
        let fm = FileManager.default
        let b = Self.browser, n = b.name
        // Everything below goes into the browser: refuse a tampered ArcPatches.app.
        guard Self.signatureValid(Bundle.main.bundleURL) else { throw PatchError.step("ArcPatches.app was modified. Reinstall it, then patch again.") }
        try withLock(b) {
            Self.recoverSwap(at: b.source)
            Self.recoverSwap(at: b.copyDestination)
            guard fm.fileExists(atPath: b.source.path) else { throw PatchError.diaMissing(n) }
            guard !b.patchedIsRunning else { throw PatchError.patchedRunning(n) }
            let startBuild = Self.info(b.source)?["CFBundleVersion"] as? String
            let inPlace = b.mode == .inPlace
            // Verify before backing up, so a tampered browser never replaces a good backup.
            let original = inPlace && Self.isPatched(b.source) ? b.backup : b.source
            guard fm.fileExists(atPath: original.path) else { throw PatchError.noBackup(n) }
            guard Self.signatureValid(original, requirement: b.requirement) else {
                throw PatchError.step("\(original.lastPathComponent) isn't an untouched \(n) signed by \(b.signer). Reinstall \(n), then patch again.")
            }
            let pristine: URL
            if inPlace {
                // A stock browser (first patch, or freshly updated) becomes the new backup.
                if !Self.isPatched(b.source) {
                    try fm.createDirectory(at: b.supportDir, withIntermediateDirectories: true)
                    let fresh = b.supportDir.appendingPathComponent(".\(b.backup.lastPathComponent).new")
                    try? fm.removeItem(at: fresh)
                    try run("/bin/cp", ["-cR", b.source.path, fresh.path], "Backing up the original \(n)")
                    try? fm.removeItem(at: b.backup)
                    try fm.moveItem(at: fresh, to: b.backup)
                }
                guard fm.fileExists(atPath: b.backup.path) else { throw PatchError.noBackup(n) }
                pristine = b.backup
            } else {
                pristine = b.source
            }

            let target = b.destination
            let parent = target.deletingLastPathComponent()
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
            let staging = parent.appendingPathComponent(".\(target.lastPathComponent).arcpatches-new")
            try? fm.removeItem(at: staging)

            // APFS clone: near-instant and takes no extra disk space until files change.
            try run("/bin/cp", ["-cR", pristine.path, staging.path], "Copying \(n)")
            let frameworks = staging.appendingPathComponent("Contents/Frameworks/arcpatches.dylib")
            try fm.copyItem(at: dylib, to: frameworks)
            try run("/usr/bin/codesign", ["-f", "-s", "-", frameworks.path], "Signing the patch")

            // Load the patch from the binary itself (a weak load command), rather than via
            // DYLD_INSERT_LIBRARIES: the patched app then doesn't accept injected code from the environment.
            let plistURL = staging.appendingPathComponent("Contents/Info.plist")
            guard var plist = NSDictionary(contentsOf: plistURL) as? [String: Any] else { throw PatchError.step("Reading Info.plist failed") }
            let exe = staging.appendingPathComponent("Contents/MacOS/\(plist["CFBundleExecutable"] as? String ?? n)")
            try run("/usr/bin/codesign", ["--remove-signature", exe.path], "Unsigning \(n)'s executable")
            try Self.insertLoadCommand(into: exe, dylib: "@executable_path/../Frameworks/arcpatches.dylib", browser: n)

            plist.removeValue(forKey: "LSEnvironment")
            if !inPlace {
                plist["SUEnableAutomaticChecks"] = false                // the copy follows the regular browser
            } else if b.isDia {
                plist.removeValue(forKey: "SUEnableAutomaticChecks")   // Dia's own updater keeps working
            }                                                           // others keep their own setting
            // Patched in place it stays the same app with the same name. Only the separate copy
            // gets its own display name, so the two can be told apart. CFBundleName never
            // changes: Dia names its profile folder after it, so both keep one profile.
            if inPlace { plist.removeValue(forKey: "CFBundleDisplayName") } else { plist["CFBundleDisplayName"] = b.appName }
            plist["ArcPatchesSourceBuild"] = Self.info(pristine)?["CFBundleVersion"]
            plist["ArcPatchesPatchVersion"] = patchVersion
            guard (plist as NSDictionary).write(to: plistURL, atomically: true) else { throw PatchError.step("Writing Info.plist failed") }

            try run("/usr/bin/codesign", ["-f", "-s", "-", "--options", "runtime", "--entitlements", entitlements.path, staging.path], "Signing \(b.appName)")
            // The build takes a while: the browser may have started, or updated itself, meanwhile.
            guard !b.patchedIsRunning else { throw PatchError.patchedRunning(n) }
            if inPlace, (Self.info(b.source)?["CFBundleVersion"] as? String) != startBuild {
                throw PatchError.step("\(n) changed while it was being patched. Patch again.")
            }
            try Self.swapIn(staging, at: target, browser: n)
            b.restoredByUser = false
        }
    }

    /// Puts the untouched original back (in place mode). ArcPatches then leaves it
    /// alone until the user patches again.
    func restoreOriginal() throws {
        let fm = FileManager.default
        let b = Self.browser, n = b.name
        guard b.mode == .inPlace else { return }
        guard !b.isRunning else { throw PatchError.patchedRunning(n) }
        try withLock(b) {
            Self.recoverSwap(at: b.source)
            if !Self.isPatched(b.source) { return }   // already stock (or never patched): no backup needed
            guard fm.fileExists(atPath: b.backup.path) else { throw PatchError.noBackup(n) }
            guard Self.signatureValid(b.backup, requirement: b.requirement) else {
                throw PatchError.step("The original \(n) backup was modified. Reinstall \(n) instead.")
            }
            let staging = b.source.deletingLastPathComponent().appendingPathComponent(".\(b.source.lastPathComponent).arcpatches-restore")
            try? fm.removeItem(at: staging)
            try run("/bin/cp", ["-cR", b.backup.path, staging.path], "Restoring the original \(n)")
            try Self.swapIn(staging, at: b.source, browser: n)
            b.restoredByUser = true
        }
    }

    /// In place → copy: put the original back, then build the copy.
    /// Copy → in place: patch the browser itself, then trash the copy.
    func switchMode(to mode: PatchMode) throws {
        let b = Self.browser
        guard mode != b.mode else { return }
        guard !b.isRunning, !Self.isRunning(b.copyDestination) else { throw PatchError.patchedRunning(b.name) }
        if mode == .copy {
            try restoreOriginal()
            b.setMode(mode)
            try patch()
            try? FileManager.default.removeItem(at: b.backup)
        } else {
            b.setMode(mode)
            do { try patch() } catch {
                b.setMode(.copy)
                throw error
            }
            try? FileManager.default.trashItem(at: b.copyDestination, resultingItemURL: nil)
        }
    }
}
