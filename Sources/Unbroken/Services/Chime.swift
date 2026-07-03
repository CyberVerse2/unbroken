import AppKit

/// A tiny "spark" sound on check-in, when the user has streak sounds on. Uses a
/// built-in system sound so there's no asset to bundle; degrades to silence if
/// the named sound isn't available.
enum Chime {
    static func playCheckIn(enabled: Bool) {
        guard enabled else { return }
        NSSound(named: "Tink")?.play()
    }
}
