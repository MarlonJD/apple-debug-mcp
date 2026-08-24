// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleDebugPluginsTests: XCTestCase {
    func testDiscoversManifestWithoutExecutingCode() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("apple-debug-mcp-plugins-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let manifest = AppleDebugPluginManifest(id: "com.example.analyzer", name: "Example Analyzer", version: "1.0.0", capabilities: ["binary-analysis"], entrypoint: "plugin-process")
        try JSONEncoder().encode(manifest).write(to: directory.appendingPathComponent("example.appledebugplugin.json"))

        let discovered = try AppleDebugPluginManifestService.discover(directory: directory.path)

        XCTAssertEqual(discovered, [manifest])
    }
}
