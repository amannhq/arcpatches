// ArcPatches's own settings, the menu bar modes, and the feature health report the
// patched browser writes at launch. Shared by the app, its window and the background job.
import AppKit

enum MenuBarMode: String, CaseIterable, Identifiable {
    case always, whenNeeded, never
    var id: String { rawValue }
    var title: String {
        switch self {
        case .always: return "Always"
        case .whenNeeded: return "When Needed"
        case .never: return "Never"
        }
    }
}

struct Health {
    var checks: [(name: String, ok: Bool)]
    var diaVersion: String
    var date: String
    var failures: Int { checks.filter { !$0.ok }.count }

    /// The selected browser's report (arcpatches/health.json for Dia).
    static var url: URL { PatchEngine.browser.healthURL }

    static func load() -> Health? {
        guard let d = try? Data(contentsOf: url),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let c = j["checks"] as? [String: Any] else { return nil }
        let checks = c.map { (name: $0.key, ok: ($0.value as? NSNumber)?.boolValue ?? false) }.sorted { $0.name < $1.name }
        return Health(checks: checks, diaVersion: j["diaVersion"] as? String ?? "?", date: j["date"] as? String ?? "")
    }
}

enum Prefs {
    static let d = UserDefaults.standard
    static var autoRepatch: Bool {
        get { d.object(forKey: "autoRepatch") as? Bool ?? true }
        set { d.set(newValue, forKey: "autoRepatch") }
    }
    static var menuBarMode: MenuBarMode {
        get { MenuBarMode(rawValue: d.string(forKey: "menuBarMode") ?? "") ?? .whenNeeded }
        set { d.set(newValue.rawValue, forKey: "menuBarMode") }
    }
    static var autoUpdateSelf: Bool {
        get { d.object(forKey: "autoUpdateSelf") as? Bool ?? true }
        set { d.set(newValue, forKey: "autoUpdateSelf") }
    }
    static var lastSelfUpdateCheck: Double {
        get { d.double(forKey: "lastSelfUpdateCheck") }
        set { d.set(newValue, forKey: "lastSelfUpdateCheck") }
    }
    /// Newer ArcPatches version seen on GitHub and not installed yet (for attention).
    static var availableSelfVersion: String? {
        get { d.string(forKey: "availableSelfVersion").flatMap { SelfUpdater.isNewer($0, than: SelfUpdater.currentVersion) ? $0 : nil } }
        set { d.set(newValue, forKey: "availableSelfVersion") }
    }
    /// A broken-feature report the user has seen and dismissed (by its date).
    static var dismissedHealthDate: String? {
        get { d.string(forKey: "dismissedHealthDate") }
        set { d.set(newValue, forKey: "dismissedHealthDate") }
    }
}

/// Why ArcPatches wants the user's attention, if at all. Shared with the background job.
func attentionReason(status: PatchStatus, lastError: String?, health: Health?) -> String? {
    if let e = lastError { return e }
    if let h = health, h.failures > 0, h.date != Prefs.dismissedHealthDate {
        return "\(h.failures) feature\(h.failures == 1 ? "" : "s") stopped working"
    }
    if case .needsPatch = status.state, PatchEngine.patchedIsRunning || !Prefs.autoRepatch {
        return "Quit \(PatchEngine.targetName) to finish patching"
    }
    if let v = Prefs.availableSelfVersion, !Prefs.autoUpdateSelf {
        return "ArcPatches \(v) is available"
    }
    return nil
}
