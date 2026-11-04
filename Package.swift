// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "KernelCore", products: [.library(name: "KernelCore", targets: ["KernelCore"])], targets: [
    .target(name: "KernelCore", path: "KernelApp/Core"),
    .testTarget(name: "KernelCoreTests", dependencies: ["KernelCore"], path: "Tests/KernelCoreTests")
])
