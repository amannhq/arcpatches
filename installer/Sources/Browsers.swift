// The browsers ArcPatches can patch, and which one it is patching. Dia is the default,
// and everything about Dia (paths, backup, settings keys) is exactly what it was
// before other browsers existed. Each other browser gets its own support folder,
// backup and settings keys, so patching one never touches another.
import AppKit

struct BrowserTarget: Equatable, Sendable {
    let id: String              // matches src/browsers/<id>/ and TweakFeature.browsers
    let name: String            // "Dia"; the patched app is "<name> Arc"
    let bundleId: String
    let defaultPath: String
    let teamId: String          // the vendor's Developer ID team: the only signer accepted for a pristine copy
    let signer: String          // who signs it, for error messages
    /// What arcpatches.dylib does in this browser, by feature folder (src/features/<name>/).
    /// tests/run.sh checks this never lists a feature the feature itself doesn't declare.
    let features: [String]
    /// Shown under the picker: what patching this browser costs, if anything.
    let caveat: String?

    static let dia = BrowserTarget(
        id: "dia", name: "Dia", bundleId: "company.thebrowser.dia", defaultPath: "/Applications/Dia.app",
        teamId: "S6N382Y83G", signer: "The Browser Company",
        features: ["commandbar", "performance", "preferences", "privacy", "shortcuts", "sidebar", "tabs"],
        caveat: nil)
    static let ardia = BrowserTarget(
        id: "ardia", name: "Ardia", bundleId: "com.ardia.browser", defaultPath: "/Applications/Ardia.app",
        teamId: "U5L5T3NGVV", signer: "its developer",
        features: ["performance"],
        caveat: "Only the Chromium switches (background networking, renderer limit) apply; Ardia already has its own sidebar "
            + "and command bar. Re-signed, Ardia acts as a dev build with a mock keychain: sites sign you out (in Ardia Arc, "
            + "and again in the original after a restore), and Chromium may delete saved passwords it can't decrypt. "
            + "Calendar access and Apple Events import may stop working.")
    /// Recognised, but nothing in arcpatches works in Chrome yet (docs/browsers.md), so it is never offered.
    static let chrome = BrowserTarget(
        id: "chrome", name: "Chrome", bundleId: "com.google.Chrome", defaultPath: "/Applications/Google Chrome.app",
        teamId: "EQHXZ8M8AV", signer: "Google", features: [], caveat: nil)

    /// Original Arc (company.thebrowser.Browser) is deliberately absent: it is discontinued.
    static let all: [BrowserTarget] = [dia, ardia, chrome]

    static func with(id: String) -> BrowserTarget? { all.first { $0.id == id } }

    /// The browser ArcPatches patches. Dia unless the user picked another.
    static var selected: BrowserTarget {
        get { UserDefaults.standard.string(forKey: "browser").flatMap(with(id:)) ?? dia }
        set { UserDefaults.standard.set(newValue.id, forKey: "browser") }
    }

    /// Installed browsers that arcpatches does something in: the picker's choices.
    static var pickable: [BrowserTarget] {
        all.filter { !$0.features.isEmpty && FileManager.default.fileExists(atPath: $0.source.path) }
    }

    var isDia: Bool { id == BrowserTarget.dia.id }

    // MARK: Paths and settings (Dia's are unchanged; the others are namespaced by id)

    /// The installed browser. ARCPATCHES_DIA_PATH (ARCPATCHES_<ID>_PATH) points it elsewhere for testing.
    var source: URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["ARCPATCHES_\(id.uppercased())_PATH"] ?? defaultPath)
    }
    var supportDir: URL {
        let base = ProcessInfo.processInfo.environment["ARCPATCHES_SUPPORT_DIR"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/arcpatches")
        return isDia ? base : base.appendingPathComponent(id)
    }
    /// The untouched original, kept while the browser itself is patched.
    var backup: URL { supportDir.appendingPathComponent("\(name)-original.app") }
    var appName: String { "\(name) Arc" }
    var copyDestination: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/\(appName).app")
    }
    var healthURL: URL { supportDir.appendingPathComponent("health.json") }
    /// Accepts only the vendor's Developer ID signature.
    var requirement: String { "anchor apple generic and certificate leaf[subject.OU] = \"\(teamId)\"" }

    private func key(_ k: String) -> String { isDia ? k : "\(k).\(id)" }
    var mode: PatchMode {
        PatchMode(rawValue: UserDefaults.standard.string(forKey: key("patchMode")) ?? "") ?? .inPlace
    }
    func setMode(_ m: PatchMode) { UserDefaults.standard.set(m.rawValue, forKey: key("patchMode")) }
    /// Set when the user chose Restore Original: don't re-patch until they ask.
    var restoredByUser: Bool {
        get { UserDefaults.standard.bool(forKey: key("restoredByUser")) }
        nonmutating set { UserDefaults.standard.set(newValue, forKey: key("restoredByUser")) }
    }

    /// The app the user runs: the browser itself (in place) or the copy.
    var destination: URL { mode == .inPlace ? source : copyDestination }
    /// What to quit before patching: the browser itself in place, the copy otherwise.
    var targetName: String { mode == .inPlace ? name : appName }
    /// Is an app ArcPatches would replace running? The browser and its backup (the passkey
    /// handoff runs it) in place; the copy otherwise.
    var patchedIsRunning: Bool { PatchEngine.isRunning(destination) || (mode == .inPlace && PatchEngine.isRunning(backup)) }
    var isRunning: Bool { PatchEngine.isRunning(source) }
}
