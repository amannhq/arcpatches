// ArcPatches's state and actions, shared by the menu bar item and the window.
import AppKit

@MainActor
final class Controller: ObservableObject {
    let engine = PatchEngine(resources: Bundle.main.resourceURL!)

    @Published private(set) var status: PatchStatus
    @Published private(set) var busy: String?
    @Published private(set) var lastError: String?
    @Published private(set) var health: Health?
    @Published private(set) var pendingRepatch = false

    // Settings, mirrored for SwiftUI bindings.
    @Published var autoRepatch = Prefs.autoRepatch { didSet { Prefs.autoRepatch = autoRepatch; tick() } }
    @Published var autoUpdateSelf = Prefs.autoUpdateSelf { didSet { Prefs.autoUpdateSelf = autoUpdateSelf; onChange?() } }
    @Published private(set) var selfUpdate: ArcPatchesRelease?
    @Published private(set) var selfUpdateResult: String?
    @Published private(set) var selfUpdateChecking = false
    @Published var openAtLogin = LoginItem.isEnabled { didSet { LoginItem.set(openAtLogin && menuBarMode == .always) } }
    @Published var menuBarMode = Prefs.menuBarMode { didSet { applyMode() } }
    /// Patch /Applications/Dia.app itself (default) rather than a separate copy.
    var patchInPlace: Bool { PatchEngine.mode == .inPlace }
    /// The browser being patched (Dia unless another is picked) and its name, for messages.
    @Published private(set) var browser = PatchEngine.browser
    var browserName: String { browser.name }

    /// Called whenever anything changes (status item refresh).
    var onChange: (() -> Void)?

    init() {
        status = PatchStatus(state: .checking)
        health = Health.load()
        refresh()
    }

    var attention: String? { attentionReason(status: status, lastError: lastError, health: health) }

    var statusLine: String {
        switch status.state {
        case .checking: return "Checking…"
        case .diaMissing: return "\(browserName) isn't installed in /Applications"
        case .notInstalled: return patchInPlace ? "\(browserName) isn't patched yet" : "Not built yet"
        case .restored: return "Original \(browserName) restored — patch to use \(PatchEngine.appName)"
        case .upToDate: return "Patched for \(browserName) \(status.diaVersion ?? "")"
        case .needsPatch(let why): return "Needs patching: \(why)" + (pendingRepatch ? " — waiting for \(PatchEngine.targetName) to quit" : "")
        }
    }

    /// `status()` runs codesign (~0.3 s): compute it off the main thread, in order, then publish it.
    private let statusQueue = DispatchQueue(label: "dev.amannhq.arcpatches.status")
    func refresh(then: (@MainActor () -> Void)? = nil) {
        if browser != PatchEngine.browser { browser = PatchEngine.browser }   // e.g. `ArcPatches --browser` meanwhile
        health = Health.load()
        let engine = self.engine
        statusQueue.async {
            let s = engine.status()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.status = s
                    self.onChange?()
                    then?()
                }
            }
        }
    }

    // MARK: Modes

    /// Always: the app stays running. When Needed / Never: a background job does the work.
    func applyMode() {
        Prefs.menuBarMode = menuBarMode
        if menuBarMode == .always {
            BackgroundAgent.uninstall()
            LoginItem.set(openAtLogin)
        } else {
            LoginItem.set(false)   // the background job runs at login instead
            BackgroundAgent.install()
        }
        onChange?()
    }

    // MARK: Browser

    /// Switches which browser ArcPatches patches. The one it leaves stays as it is
    /// (patched or not); its settings, backup and health report are kept for later.
    func selectBrowser(_ b: BrowserTarget) {
        guard busy == nil, b != browser else { return }
        BrowserTarget.selected = b
        browser = b
        lastError = nil
        updateHint = nil
        pendingRepatch = false
        if BackgroundAgent.isInstalled { BackgroundAgent.install() }   // watch the new browser's Info.plist
        tick()
    }

    // MARK: Automation

    func tick() {
        refresh { [self] in
            guard busy == nil else { return }
            if Date().timeIntervalSince1970 - Prefs.lastSelfUpdateCheck > 24 * 3600 { checkSelfUpdate() }
            // After a failure, wait for the user (Patch, or dismissing the error) instead of retrying every tick.
            if case .needsPatch = status.state, (autoRepatch && lastError == nil) || pendingRepatch {
                if PatchEngine.patchedIsRunning { pendingRepatch = true } else { repatch(auto: true) }
            }
            onChange?()
        }
    }

    /// The browser updates itself. In place, Dia Arc keeps Dia's own updater; this is the fallback:
    /// put the original Dia back, open it to update, and re-patch once it quits.
    /// In copy mode: open the regular Dia; ArcPatches re-patches from the new version.
    @Published private(set) var updateHint: String?

    func updateDia() {
        guard busy == nil else { return }
        if PatchEngine.patchedIsRunning {
            updateHint = "Quit \(PatchEngine.targetName) first" + (patchInPlace ? "." : " — both share one profile.")
            return
        }
        let n = browserName
        updateHint = "In \(n), choose \(n) ▸ Check for Updates. Quit \(n) when it's done; ArcPatches re-patches automatically."
        guard patchInPlace else {
            NSWorkspace.shared.openApplication(at: PatchEngine.source, configuration: .init())
            return
        }
        run("Restoring the original \(n)…", { try $0.restoreOriginal(); PatchEngine.restoredByUser = false }) { ok in
            guard ok else { return }
            self.pendingRepatch = true
            NSWorkspace.shared.openApplication(at: PatchEngine.source, configuration: .init())
        }
    }

    /// Puts the untouched browser back; ArcPatches leaves it alone until Patch is clicked.
    func restoreOriginal() {
        if PatchEngine.diaIsRunning { lastError = "Quit \(browserName) first."; refresh(); return }
        run("Restoring the original \(browserName)…", { try $0.restoreOriginal() }) { _ in }
    }

    func setPatchInPlace(_ on: Bool) {
        let mode: PatchMode = on ? .inPlace : .copy
        guard mode != PatchEngine.mode else { return }
        if PatchEngine.diaIsRunning || PatchEngine.isRunning(PatchEngine.copyDestination) {
            lastError = "Quit \(browserName) first, then switch."
            refresh()
            return
        }
        run(on ? "Patching \(browserName) directly…" : "Restoring \(browserName) and building \(PatchEngine.appName)…", { try $0.switchMode(to: mode) }) { _ in }
    }

    /// Runs an engine job off the main thread, showing `label` while it works.
    private func run(_ label: String, _ job: @escaping @Sendable (PatchEngine) throws -> Void, then: @escaping (Bool) -> Void) {
        guard busy == nil else { return }
        busy = label
        onChange?()
        let engine = self.engine
        Task.detached {
            let result = Result { try job(engine) }
            await MainActor.run {
                self.busy = nil
                switch result {
                case .success: self.lastError = nil
                case .failure(let e): self.lastError = e.localizedDescription
                }
                then(result.isSuccess)
                self.refresh()
            }
        }
    }

    func repatch(auto: Bool = false) {
        guard busy == nil else { return }
        if PatchEngine.patchedIsRunning {
            pendingRepatch = true
            if !auto { notifyUser("Quit \(PatchEngine.targetName) to finish patching", "ArcPatches will patch it as soon as it closes.") }
            onChange?()
            return
        }
        busy = "Patching…"
        onChange?()
        let reason: String = { if case .needsPatch(let r) = status.state { return r }; return "Rebuilt" }()
        let engine = self.engine
        Task.detached {
            let result = Result { try engine.patch() }
            await MainActor.run {
                self.busy = nil
                self.pendingRepatch = false
                switch result {
                case .success:
                    self.lastError = nil
                    if auto { notifyUser("\(PatchEngine.appName) is ready", "\(reason) — patched for \(PatchEngine.browser.name) \(PatchEngine.version(PatchEngine.source) ?? "").") }
                case .failure(PatchError.busy):
                    break
                case .failure(PatchError.patchedRunning):
                    self.pendingRepatch = true   // the browser started meanwhile: patch once it quits
                case .failure(let e):
                    self.lastError = e.localizedDescription
                    notifyUser("Couldn't patch \(PatchEngine.browser.name)", e.localizedDescription)
                }
                self.refresh()
            }
        }
    }

    // MARK: Updating ArcPatches itself

    func checkSelfUpdate(manual: Bool = false) {
        guard !selfUpdateChecking else { return }
        selfUpdateChecking = true
        Task {
            do {
                let r = try await SelfUpdater.latest()
                Prefs.lastSelfUpdateCheck = Date().timeIntervalSince1970
                selfUpdate = r
                Prefs.availableSelfVersion = r?.version
                selfUpdateResult = r.map { "ArcPatches \($0.version) is available" } ?? "ArcPatches \(SelfUpdater.currentVersion) is the latest"
                if let r, Prefs.autoUpdateSelf, !manual { installSelfUpdate(r) }
            } catch {
                selfUpdateResult = error.localizedDescription
            }
            selfUpdateChecking = false
            onChange?()
        }
    }

    func installSelfUpdate(_ r: ArcPatchesRelease) {
        guard busy == nil else { return }
        busy = "Updating ArcPatches to \(r.version)…"
        onChange?()
        Task {
            do {
                try await SelfUpdater.install(r)
                Prefs.availableSelfVersion = nil
                notifyUser("ArcPatches updated to \(r.version)", "\(PatchEngine.appName) will be re-patched with it.")
                SelfUpdater.relaunch()
                NSApp.terminate(nil)
            } catch {
                busy = nil
                lastError = error.localizedDescription
                refresh()
            }
        }
    }

    func dismissHealth() {
        Prefs.dismissedHealthDate = health?.date
        refresh()
    }

    func clearError() {
        lastError = nil
        refresh()
    }

    func openPatchedDia() {
        guard busy == nil else { return }   // mid-patch, the old bundle is about to be replaced
        if !PatchEngine.isPatched(PatchEngine.destination) { repatch(); return }
        NSWorkspace.shared.openApplication(at: PatchEngine.destination, configuration: .init())
    }
}

extension Result { var isSuccess: Bool { if case .success = self { return true }; return false } }

func notifyUser(_ title: String, _ body: String) {
    Task { await notify(title, body) }
}
