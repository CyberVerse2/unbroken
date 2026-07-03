import AppKit
import Foundation

/// Registers the bundled Bricolage Grotesque + Hanken Grotesk TTFs so
/// `Font.custom("Bricolage Grotesque", …)` resolves.
///
/// Fonts ship as loose .ttf in the app bundle's Resources (copied there by
/// `make app`). The preview harness passes an explicit directory instead.
@MainActor
enum FontLoader {
    private static var didRegister = false

    /// Register every .ttf found in `directory` (default: the main bundle's
    /// Resources). Idempotent; safe to call more than once.
    static func register(from directory: URL? = Bundle.main.resourceURL) {
        guard !didRegister else { return }
        didRegister = true
        guard let directory else { return }
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return }
        for url in items where url.pathExtension.lowercased() == "ttf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
