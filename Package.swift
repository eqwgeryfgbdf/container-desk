// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ContainerDesk", platforms: [.macOS("26.0")], products: [.executable(name: "ContainerDesk", targets: ["ContainerDesk"])], targets: [.executableTarget(name: "ContainerDesk", path: "Sources", swiftSettings: [.swiftLanguageMode(.v5)])])
