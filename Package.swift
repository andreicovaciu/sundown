// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "Sundown",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "Sundown", targets: ["Sundown"])
  ],
  targets: [
    .target(name: "SundownCore"),
    .executableTarget(
      name: "Sundown",
      dependencies: ["SundownCore"]
    ),
    .testTarget(
      name: "SundownCoreTests",
      dependencies: ["SundownCore"]
    )
  ]
)
