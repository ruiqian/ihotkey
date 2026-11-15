// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "iHotkey",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "iHotkey", targets: ["iHotkey"])
    ],
    targets: [
        // Pure logic: key combos, snap geometry, config, conflict detection.
        // No AppKit dependency so it is fully unit-testable.
        .target(
            name: "iHotkeyCore",
            path: "Sources/iHotkeyCore"
        ),
        // The macOS app: menu bar, settings UI, hotkeys, window manager.
        .executableTarget(
            name: "iHotkey",
            dependencies: ["iHotkeyCore"],
            path: "Sources/iHotkey",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "iHotkeyCoreTests",
            dependencies: ["iHotkeyCore"],
            path: "Tests/iHotkeyCoreTests"
        )
    ]
)
