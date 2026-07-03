import Foundation
import ServiceManagement

/// Real launch-at-login via `SMAppService`. For a menu-bar app that has to be
/// present every day, this is the difference between "a thing I opened once" and
/// "a thing that's just there" — so the settings toggle drives the actual login
/// item, not a dead preference.
enum LaunchAtLogin {
    /// Whether the app is currently registered to open at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register / unregister the login item. No-ops (and logs) if the process
    /// isn't a real app bundle — e.g. the preview harness run via `swift run`.
    static func set(_ enabled: Bool) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        do {
            let service = SMAppService.mainApp
            if enabled {
                if service.status != .enabled { try service.register() }
            } else {
                if service.status == .enabled { try service.unregister() }
            }
        } catch {
            NSLog("Unbroken LaunchAtLogin failed: \(error.localizedDescription)")
        }
    }
}
