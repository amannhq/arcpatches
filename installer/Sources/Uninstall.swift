// Uninstall: put every patched browser back, remove the background job and the login
// item, and list what is left for the user to delete (ArcPatches never deletes the
// backup of an original browser itself).
//   ArcPatches.app/Contents/MacOS/ArcPatches --uninstall, or the menu's "Uninstall ArcPatches…"
import AppKit

enum Uninstaller {
    /// Runs off the main thread. Stops at the first browser it can't restore (e.g. still
    /// running), before removing anything else, so running it again finishes the job.
    /// Returns what's left, one line each.
    static func run(engine: PatchEngine) throws -> [String] {
        let fm = FileManager.default
        let selected = BrowserTarget.selected
        defer { BrowserTarget.selected = selected }
        var restored: [String] = []
        for b in BrowserTarget.all {
            BrowserTarget.selected = b   // the engine works on the selected browser
            PatchEngine.recoverSwapIfIdle(b)
            if b.mode == .inPlace, PatchEngine.isPatched(b.source) {
                try engine.restoreOriginal()
                restored.append("Restored the original \(b.name).")
            }
            if PatchEngine.isPatched(b.copyDestination) {
                guard !PatchEngine.isRunning(b.copyDestination) else { throw PatchError.patchedRunning(b.appName) }
                try fm.trashItem(at: b.copyDestination, resultingItemURL: nil)
                restored.append("Moved \(b.copyDestination.path) to the Trash.")
            }
        }
        BackgroundAgent.uninstall()
        LoginItem.set(false)

        var left = restored + ["Removed the background job and the login item."]
        let support = BrowserTarget.dia.supportDir
        if fm.fileExists(atPath: support.path) {
            left.append("Left: \(support.path) (backups of the original browsers, health reports). Delete it when you no longer need them.")
        }
        left.append("Left: ArcPatches' settings. Remove with: defaults delete dev.amannhq.arcpatches")
        left.append("Left: the arcpatches.* settings in each browser (e.g. defaults read company.thebrowser.dia | grep arcpatches). They do nothing without the patch.")
        left.append("Left: \(Bundle.main.bundlePath). Quit ArcPatches and move it to the Trash.")
        return left
    }
}

extension Controller {
    /// The menu's "Uninstall ArcPatches…": confirm, uninstall, show what's left, quit.
    func confirmUninstall() {
        guard busy == nil else { return }
        let ask = NSAlert()
        ask.messageText = "Uninstall ArcPatches?"
        ask.informativeText = "This puts the original browser back where it was patched, and removes ArcPatches' "
            + "background job and login item. Quit the patched browser first."
        ask.addButton(withTitle: "Uninstall")
        ask.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard ask.runModal() == .alertFirstButtonReturn else { return }
        final class Lines: @unchecked Sendable { var value: [String] = [] }
        let left = Lines()
        run("Uninstalling…", { left.value = try Uninstaller.run(engine: $0) }) { ok in
            let done = NSAlert()
            done.messageText = ok ? "ArcPatches is uninstalled" : "Couldn't finish uninstalling"
            done.informativeText = ok ? left.value.joined(separator: "\n\n")
                : (self.lastError ?? "") + "\n\nNothing else was removed. Fix this, then choose Uninstall again."
            NSApp.activate(ignoringOtherApps: true)
            done.runModal()
            if ok { NSApp.terminate(nil) }
        }
    }
}
