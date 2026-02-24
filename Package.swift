// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "earfuse-menubar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "EarFuseApp", targets: ["EarFuseApp"])
    ],
    targets: [
        .target(name: "Core", path: "Core/Shared"),
        .target(name: "Capture", path: "Audio/Capture"),
        .target(
            name: "Meter",
            dependencies: ["Core"],
            path: "Audio/Meter"
        ),
        .target(
            name: "Policy",
            dependencies: ["Core", "Profiles"],
            path: "Core/Policy"
        ),
        .target(name: "Profiles", path: "Core/Profiles"),
        .target(name: "Alerts", dependencies: ["Core"], path: "Core/Alerts"),
        .target(
            name: "Fuse",
            dependencies: ["Core", "Profiles"],
            path: "Core/Fuse"
        ),
        .target(
            name: "Logging",
            dependencies: ["Core"],
            path: "Core/Logging"
        ),
        .target(
            name: "Audio",
            dependencies: [
                "Core",
                "Capture",
                "Meter",
                "Policy",
                "Profiles",
                "Alerts",
                "Fuse",
                "Logging"
            ],
            path: "Audio/Service"
        ),
        .target(
            name: "SettingsUI",
            dependencies: ["Profiles", "Capture"],
            path: "SettingsUI"
        ),
        .target(
            name: "MenuBarUI",
            dependencies: ["Audio", "SettingsUI", "Profiles", "Logging"],
            path: "MenuBarUI"
        ),
        .executableTarget(
            name: "EarFuseApp",
            dependencies: ["MenuBarUI", "Audio", "Profiles"],
            path: "App"
        )
    ]
)
