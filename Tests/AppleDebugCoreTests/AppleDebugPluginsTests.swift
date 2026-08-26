// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
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

    func testRejectsOversizedManifestBeforeDecoding() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("apple-debug-mcp-plugins-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data(repeating: 65, count: 64 * 1024 + 1)
            .write(to: directory.appendingPathComponent("large.appledebugplugin.json"))

        XCTAssertThrowsError(try AppleDebugPluginManifestService.discover(directory: directory.path)) { error in
            XCTAssertEqual(error as? AppleDebugPluginError, .manifestTooLarge)
        }
    }

    func testRejectsSymlinkManifest() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("apple-debug-mcp-plugins-\(UUID().uuidString)")
        let manifestURL = directory.appendingPathComponent("manifest.json")
        let linkURL = directory.appendingPathComponent("link.appledebugplugin.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("{}".utf8).write(to: manifestURL)
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: manifestURL)

        XCTAssertThrowsError(try AppleDebugPluginManifestService.discover(directory: directory.path)) { error in
            guard case .invalidManifest = error as? AppleDebugPluginError else {
                return XCTFail("Expected invalidManifest, got \(error)")
            }
        }
    }
}
