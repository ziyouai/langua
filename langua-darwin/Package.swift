// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "langua-darwin",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "LangObjC",
            path: "Sources/LangObjC",
            publicHeadersPath: "."
        ),
        .executableTarget(
            name: "Langua",
            dependencies: ["LangObjC"],
            path: "Sources/Langua",
            resources: [
                .copy("Resources/pinyin-data.js"),
                .copy("Resources/pinyin-ext.json"),
                .copy("Resources/segmenter.js"),
                .copy("Resources/units-data.js"),
            ]
        )
    ]
)
