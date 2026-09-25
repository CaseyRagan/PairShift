// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PairShift",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PairShiftCore", targets: ["PairShiftCore"]),
        .executable(name: "pairshift-verify", targets: ["PairShiftVerifier"])
    ],
    targets: [
        .target(name: "PairShiftCore"),
        .executableTarget(name: "PairShiftVerifier", dependencies: ["PairShiftCore"], exclude: ["verification-report.json"]),
        .testTarget(name: "PairShiftCoreTests", dependencies: ["PairShiftCore"])
    ]
)
