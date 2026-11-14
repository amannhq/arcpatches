// ArcPatches: keeps Dia Arc patched.
//  - Patches Dia itself (or, optionally, a separate copy) and re-patches when Dia
//    (or arcpatches itself) changes.
//  - Dia updates itself as usual; ArcPatches re-patches afterwards.
//  - Shows which arcpatches features still work after a Dia update.
// Opening the app shows its window. The menu bar icon is Always / When Needed / Never.
import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private let c = Controller()
    private let launchedForAttention = CommandLine.arguments.contains("--attention")
    private let launchedAtLogin = CommandLine.arguments.contains("--login")

    func applicationDidFinishLaunching(_ n: Notification) {
        // ArcPatches may have moved since the job or login item was written: point them here.
        if (BackgroundAgent.isInstalled && !BackgroundAgent.pointsHere) || (LoginItem.isEnabled && !LoginItem.pointsHere) { c.applyMode() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false   // else isEnabled below is ignored
        statusItem.menu = menu
        c.onChange = { [weak self] in self?.refresh() }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }

        // Re-check when the browser or its Arc build quits (that's when patching/updating is possible).
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == PatchEngine.browser.bundleId else { return }
            MainActor.assumeIsolated { self?.c.tick() }
        }
        let local = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.c.tick() } }
        local.tolerance = 30

        // First launch: set up the background job for the default mode.
        if UserDefaults.standard.string(forKey: "menuBarMode") == nil { c.applyMode() }

        Handoff.shared.onFinish = { [weak self] in self?.refresh() }
        c.tick()
        // Launched to open a arcpatches:// link (the passkey handoff): no window.
        let openedForURL = (n.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool) == false
        if !launchedForAttention && !launchedAtLogin && !openedForURL { showWindow() }
        refresh()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "arcpatches" && url.host == "handoff" { Handoff.shared.start() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showWindow()
        return true
    }

    // MARK: Visibility

    private var iconWanted: Bool {
        switch c.menuBarMode {
        case .always: return true
        case .whenNeeded: return c.attention != nil || c.busy != nil
        case .never: return false
        }
    }

    private func refresh() {
        statusItem.isVisible = iconWanted
        statusItem.button?.image = ArcPatchesIcon.menuBarImage(c.busy != nil ? .busy : (c.attention != nil ? .attention : .none))
        statusItem.button?.toolTip = c.attention.map { "ArcPatches — \($0)" } ?? "ArcPatches"
        quitIfIdle()
    }

    /// Outside "Always", ArcPatches only runs while it has something to show.
    private func quitIfIdle() {
        guard c.menuBarMode != .always, c.busy == nil, !iconWanted, window?.isVisible != true, !Handoff.shared.isActive else { return }
        // Let any pending work (e.g. a just-started update check) settle first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.c.menuBarMode != .always, self.c.busy == nil, !self.iconWanted, self.window?.isVisible != true,
                  !Handoff.shared.isActive else { return }
            NSApp.terminate(nil)
        }
    }

    @objc func showWindow() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: ArcPatchesWindowView(c: c)))
            w.title = "ArcPatches"
            w.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            window = w
        }
        c.refresh()
        NSApp.setActivationPolicy(.regular)   // Dock icon + ⌘Tab while the window is open
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        DispatchQueue.main.async { self.quitIfIdle() }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        actions = [:]
        menu.addItem(header("ArcPatches"))
        menu.addItem(info(c.busy ?? c.statusLine))
        if let a = c.attention { menu.addItem(info("⚠︎ \(a)")) }
        menu.addItem(.separator())
        let open = item("Open \(PatchEngine.appName)", "o") { $0.c.openPatchedDia() }
        open.isEnabled = c.busy == nil
        menu.addItem(open)
        if let r = c.selfUpdate {
            menu.addItem(item("Update ArcPatches to \(r.version)", "") { $0.c.installSelfUpdate(r) })
        }
        menu.addItem(item("Update \(c.browserName)…", "u") { $0.c.updateDia(); $0.showWindow() })
        let patch = item(c.status.isUpToDate ? "Rebuild \(PatchEngine.appName)" : "Patch Now", "p") { $0.c.repatch() }
        patch.isEnabled = c.busy == nil
        menu.addItem(patch)
        menu.addItem(.separator())
        menu.addItem(item("Settings…", ",") { $0.showWindow() })
        menu.addItem(item("ArcPatches on GitHub", "") { _ in NSWorkspace.shared.open(URL(string: "https://github.com/\(SelfUpdater.repo)")!) })
        menu.addItem(item("Quit ArcPatches", "q") { _ in NSApp.terminate(nil) })
    }

    private func header(_ s: String) -> NSMenuItem {
        let i = NSMenuItem(title: s, action: nil, keyEquivalent: "")
        i.attributedTitle = NSAttributedString(string: s, attributes: [.font: NSFont.boldSystemFont(ofSize: 13)])
        i.isEnabled = false
        return i
    }
    private func info(_ s: String) -> NSMenuItem { let i = NSMenuItem(title: s, action: nil, keyEquivalent: ""); i.isEnabled = false; return i }

    private var actions: [Int: (AppDelegate) -> Void] = [:]
    private func item(_ title: String, _ key: String, _ run: @escaping (AppDelegate) -> Void) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: #selector(runMenuAction(_:)), keyEquivalent: key)
        i.target = self
        i.tag = actions.count
        actions[i.tag] = run
        return i
    }
    @objc private func runMenuAction(_ sender: NSMenuItem) { actions[sender.tag]?(self) }
}

// Diagnostics: ArcPatches.app/Contents/MacOS/ArcPatches --status | --patch | --background-check | ...
let cliFlags: Set<String> = ["--status", "--browser", "--patch", "--update-from", "--background-check", "--background-mode", "--make-icon", "--restore", "--mode", "--help"]
if let flag = CommandLine.arguments.dropFirst().first, cliFlags.contains(flag) {
    let engine = PatchEngine(resources: Bundle.main.resourceURL!)
    var finished = false
    Task {
        defer { DispatchQueue.main.async { finished = true } }
        do {
            switch flag {
            case "--status":
                let s = engine.status()
                let n = PatchEngine.browser.name
                print("browser: \(PatchEngine.browser.id)  mode: \(PatchEngine.mode.rawValue)  target: \(PatchEngine.destination.path)  running: \(PatchEngine.patchedIsRunning)  \(n) running: \(PatchEngine.diaIsRunning)")
                print("\(n): \(s.diaVersion ?? "missing")  \(PatchEngine.appName): \(s.patchedFrom ?? "not built")  patch: \(engine.patchVersion)  state: \(s.state)  menu bar: \(Prefs.menuBarMode.rawValue)  background job: \(BackgroundAgent.isInstalled)")
            case "--browser":
                // Which browser to patch: dia (default), or another installed one arcpatches supports.
                guard CommandLine.arguments.count > 2, let b = BrowserTarget.with(id: CommandLine.arguments[2]), BrowserTarget.pickable.contains(b) else {
                    print("usage: --browser \(BrowserTarget.pickable.map(\.id).joined(separator: "|"))  (now: \(PatchEngine.browser.id))"); break
                }
                BrowserTarget.selected = b
                if BackgroundAgent.isInstalled { BackgroundAgent.install() }
                print("Browser: \(b.name)")
            case "--background-mode":
                let on = CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "on"
                if on { LoginItem.set(false); BackgroundAgent.install() } else { BackgroundAgent.uninstall() }
                print("Background mode \(on ? "on" : "off")")
            case "--update-from":
                // Dev: install a specific signed build, e.g. from a local server.
                let a = CommandLine.arguments
                guard a.count == 4, let zip = URL(string: a[2]), let sig = URL(string: a[2] + ".sig") else { print("usage: --update-from <zip-url> <version>"); break }
                try await SelfUpdater.install(ArcPatchesRelease(version: a[3], zip: zip, signature: sig, notesURL: nil))
                print("Installed ArcPatches \(a[3]) at \(Bundle.main.bundlePath)")
            case "--background-check":
                await runBackgroundCheck()
            case "--make-icon":
                try ArcPatchesIcon.writeICNS(to: URL(fileURLWithPath: CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "."))
            case "--restore":
                try engine.restoreOriginal()
                print("Restored: \(PatchEngine.version(PatchEngine.source) ?? "?")")
            case "--mode":
                guard CommandLine.arguments.count > 2, let m = PatchMode(rawValue: CommandLine.arguments[2]) else { print("usage: --mode inPlace|copy"); break }
                try engine.switchMode(to: m)
                print("Mode: \(PatchEngine.mode.rawValue)")
            case "--patch":
                try engine.patch()
                print("Patched: \(PatchEngine.version(PatchEngine.destination) ?? "?")")
            default:
                print("usage: ArcPatches [--status | --browser <id> | --patch | --restore | --mode inPlace|copy | --background-check | --background-mode on|off]")
            }
        } catch {
            print("error: \(error.localizedDescription)")
        }
    }
    // Run the main run loop rather than block it: NSWorkspace.runningApplications only updates while it runs.
    while !finished { RunLoop.main.run(mode: .default, before: .distantFuture) }
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
