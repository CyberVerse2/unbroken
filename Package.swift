// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Unbroken",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "UnbrokenCore"),
        .executableTarget(
            name: "Unbroken",
            dependencies: ["UnbrokenCore"]
        ),
        .testTarget(
            name: "UnbrokenCoreTests",
            dependencies: ["UnbrokenCore"]
        ),
        // Icon-preview harness: renders every menu-bar icon state to PNGs for
        // human review. Shares MenuBarIcon.swift with the app via a symlink in
        // Tools/iconpreview (executable targets can't be imported).
        .executableTarget(
            name: "iconpreview",
            dependencies: ["UnbrokenCore"],
            path: "Tools/iconpreview"
        ),
        // UI-preview harness: renders the popover with sample data to PNGs for
        // review without a GUI session. Shares the UI sources via symlinks.
        .executableTarget(
            name: "uipreview",
            dependencies: ["UnbrokenCore"],
            path: "Tools/uipreview"
        ),
        // Second preview harness so the window/widget agent can render without
        // colliding with uipreview (owned by the popover agent).
        .executableTarget(
            name: "windowpreview",
            dependencies: ["UnbrokenCore"],
            path: "Tools/windowpreview"
        ),
        // `unbroken` command-line tool: check in from scripts/terminals.
        // First external EntrySource — what makes "for anything" real.
        .executableTarget(
            name: "unbroken-cli",
            dependencies: ["UnbrokenCore"],
            path: "Sources/UnbrokenCLI"
        ),
        // Widget extension binary, packaged into the app bundle by `make app`.
        .executableTarget(
            name: "UnbrokenWidget",
            dependencies: ["UnbrokenCore"],
            path: "Sources/UnbrokenWidget"
        ),
    ]
)
