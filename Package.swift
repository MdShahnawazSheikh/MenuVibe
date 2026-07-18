// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MenuVibe",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MenuVibe", targets: ["MenuVibe"])
    ],
    dependencies: [
        // Intentionally dependency-free. MenuVibe leans on the system SDK only
        // (AppKit, SwiftUI, Carbon, ApplicationServices, ServiceManagement) so the
        // binary stays tiny and the supply-chain surface stays at zero.
    ],
    targets: [
        .executableTarget(
            name: "MenuVibe",
            path: "Sources/MenuVibe",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .testTarget(
            name: "MenuVibeTests",
            dependencies: ["MenuVibe"],
            path: "Tests/MenuVibeTests"
        )
    ]
)
