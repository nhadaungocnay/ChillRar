// swift-tools-version:5.9
import PackageDescription

// libunrar.a is produced by `Scripts/build_unrar.sh` (or `make unrar`).
let unrarLibDir = Context.packageDirectory + "/Vendor/lib"

let package = Package(
    name: "ChillRar",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "RarKit", targets: ["RarKit"]),
        .executable(name: "ChillRar", targets: ["ChillRar"]),
        .executable(name: "chillrar", targets: ["chillrar-cli"]),
    ],
    targets: [
        // Thin C module exposing the UnRAR DLL API (dll.hpp) to Swift.
        .target(
            name: "CUnrar",
            path: "Sources/CUnrar",
            linkerSettings: [
                .unsafeFlags(["-L\(unrarLibDir)"]),
                .linkedLibrary("unrar"),
                .linkedLibrary("c++"),
            ]
        ),
        .target(
            name: "RarKit",
            dependencies: ["CUnrar"],
            path: "Sources/RarKit"
        ),
        .executableTarget(
            name: "ChillRar",
            dependencies: ["RarKit"],
            path: "Sources/ChillRar"
        ),
        .executableTarget(
            name: "chillrar-cli",
            dependencies: ["RarKit"],
            path: "Sources/chillrar-cli"
        ),
    ]
)
