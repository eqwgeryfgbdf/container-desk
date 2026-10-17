// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "ContainerDesk", platforms: [.macOS("26.0")],
    products: [.executable(name: "ContainerDesk", targets: ["ContainerDesk"])],
    dependencies: [.package(url: "https://github.com/jpsim/Yams.git", exact: "6.2.2")],
    targets: [.executableTarget(name: "ContainerDesk", dependencies: [.product(name: "Yams", package: "Yams")], path: "Sources", swiftSettings: [.swiftLanguageMode(.v5)])]
)
