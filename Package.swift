// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "KeyPilot",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "KeyPilot", targets: ["KeyPilot"])
    ],
    targets: [
        // Pure logic: key combos, snap geometry, config, conflict detection.
        // No AppKit dependency so it is fully unit-testable.
        .target(
            name: "KeyPilotCore",
            path: "Sources/KeyPilotCore"
        ),
        // The macOS app: menu bar, settings UI, hotkeys, window manager.
        .executableTarget(
            name: "KeyPilot",
            dependencies: ["KeyPilotCore"],
            path: "Sources/KeyPilot",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "KeyPilotCoreTests",
            dependencies: ["KeyPilotCore"],
            path: "Tests/KeyPilotCoreTests"
        )
    ]
)
