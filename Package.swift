// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "WakeMyMac",
    platforms: [.macOS(.v13)],
    targets: [
        // Shared model: rules, next-occurrence math, XPC protocol, constants.
        .target(name: "WakeCore"),

        // Root launchd daemon: owns IOPMSchedulePowerEvent, re-arms one-shot
        // events, serves the app over XPC.
        .executableTarget(
            name: "wakemymacd",
            dependencies: ["WakeCore"],
            linkerSettings: [.linkedFramework("IOKit")]
        ),

        // Menu bar app (SwiftUI MenuBarExtra).
        .executableTarget(
            name: "WakeMyMac",
            dependencies: ["WakeCore"]
        ),

        .testTarget(name: "WakeCoreTests", dependencies: ["WakeCore"]),
    ]
)
