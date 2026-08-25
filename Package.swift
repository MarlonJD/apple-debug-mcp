// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "apple-debug-mcp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AppleDebugCore",
            targets: ["AppleDebugCore"]
        ),
        .executable(
            name: "apple-debug-mcp",
            targets: ["AppleDebugMCP"]
        ),
        .executable(
            name: "apple-debug-workbench",
            targets: ["AppleDebugWorkbench"]
        ),
        .executable(
            name: "apple-debug-menubar",
            targets: ["AppleDebugMenuBar"]
        ),
        .executable(
            name: "apple-debug-plugin-host",
            targets: ["AppleDebugPluginHost"]
        ),
        .executable(
            name: "apple-debug-plugin-xpc-service",
            targets: ["AppleDebugPluginXPCService"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/modelcontextprotocol/swift-sdk.git",
            from: "0.11.0"
        ),
        .package(
            url: "https://github.com/apple/swift-nio.git",
            from: "2.101.3"
        )
    ],
    targets: [
        .target(
            name: "AppleDebugCore"
        ),
        .executableTarget(
            name: "AppleDebugMCP",
            dependencies: [
                "AppleDebugCore",
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio")
            ]
        ),
        .executableTarget(
            name: "AppleDebugWorkbench",
            dependencies: ["AppleDebugCore"]
        ),
        .executableTarget(
            name: "AppleDebugMenuBar",
            dependencies: ["AppleDebugCore"]
        ),
        .executableTarget(
            name: "AppleDebugPluginHost",
            dependencies: ["AppleDebugCore"]
        ),
        .executableTarget(
            name: "AppleDebugPluginXPCService",
            dependencies: ["AppleDebugCore"]
        ),
        .testTarget(
            name: "AppleDebugCoreTests",
            dependencies: ["AppleDebugCore"]
        )
    ]
)
