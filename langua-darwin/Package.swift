// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "langua-darwin",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Langua",
            path: "Sources/Langua",
            resources: [
                .copy("Resources/pinyin-data.js"),
                .copy("Resources/segmenter.js"),
                .copy("Resources/units-data.js"),
            ]
        )
    ]
)
