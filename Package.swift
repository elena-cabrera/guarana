// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Guarana",
    platforms: [.macOS(.v13)],
    targets: [
        // Shared drawing code for the guarana fruit (menu bar icon, app icon, installer art).
        .target(name: "GuaranaArt"),
        // The menu bar app itself.
        .executableTarget(name: "Guarana", dependencies: ["GuaranaArt"]),
        // Renders the app icon, DMG background and web images: `swift run GuaranaAssets <outdir>`.
        .executableTarget(name: "GuaranaAssets", dependencies: ["GuaranaArt"]),
    ]
)
