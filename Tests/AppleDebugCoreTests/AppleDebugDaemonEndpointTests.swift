// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppleDebugCore
import Foundation
import XCTest

final class AppleDebugDaemonEndpointTests: XCTestCase {
    func testEndpointRoundTripAndOwnedRemoval() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-daemon-endpoint-\(UUID().uuidString)")
        let fileURL = directory.appendingPathComponent("endpoint.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let endpoint = AppleDebugDaemonEndpoint(
            url: URL(string: "http://127.0.0.1:49152/mcp")!,
            token: String(repeating: "a", count: 64),
            pid: 1234
        )
        try endpoint.write(to: fileURL)

        let loaded = try AppleDebugDaemonEndpoint.load(from: fileURL)
        XCTAssertEqual(loaded.schemaVersion, endpoint.schemaVersion)
        XCTAssertEqual(loaded.url, endpoint.url)
        XCTAssertEqual(loaded.token, endpoint.token)
        XCTAssertEqual(loaded.pid, endpoint.pid)
        XCTAssertLessThan(abs(loaded.startedAt.timeIntervalSince(endpoint.startedAt)), 1)
        AppleDebugDaemonEndpoint.removeIfOwned(
            pid: endpoint.pid,
            token: endpoint.token,
            from: fileURL
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testEndpointRejectsNonLoopbackURL() throws {
        let endpoint = AppleDebugDaemonEndpoint(
            url: URL(string: "http://localhost:49152/mcp")!,
            token: String(repeating: "a", count: 64),
            pid: 1234
        )

        XCTAssertThrowsError(try endpoint.validate())
    }

    func testEndpointLoadRejectsOversizedFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-daemon-endpoint-\(UUID().uuidString)")
        let fileURL = directory.appendingPathComponent("endpoint.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(repeating: 65, count: 64 * 1024 + 1).write(to: fileURL)

        XCTAssertThrowsError(try AppleDebugDaemonEndpoint.load(from: fileURL)) { error in
            guard case .invalidFile = error as? EndpointError else {
                return XCTFail("Expected invalidFile, got \(error)")
            }
        }
    }

    func testEndpointLoadRejectsSymlink() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-daemon-endpoint-\(UUID().uuidString)")
        let fileURL = directory.appendingPathComponent("endpoint.json")
        let linkURL = directory.appendingPathComponent("link.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let endpoint = AppleDebugDaemonEndpoint(
            url: URL(string: "http://127.0.0.1:49152/mcp")!,
            token: String(repeating: "a", count: 64),
            pid: 1234
        )
        try endpoint.write(to: fileURL)
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: fileURL)

        XCTAssertThrowsError(try AppleDebugDaemonEndpoint.load(from: linkURL)) { error in
            guard case .invalidFile = error as? EndpointError else {
                return XCTFail("Expected invalidFile, got \(error)")
            }
        }
    }
}
