// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import XCTest
@testable import AppleDebugCore

final class BoundedFileTests: XCTestCase {
    func testReadsRegularFileWithinLimit() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-bounded-file-\(UUID().uuidString)")
        let file = directory.appendingPathComponent("input.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: file)

        XCTAssertEqual(try AppleBoundedFile.readData(atPath: file.path, maximumSize: 16), Data("{}".utf8))
    }

    func testRejectsOversizedFileBeforeDecoding() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-bounded-file-\(UUID().uuidString)")
        let file = directory.appendingPathComponent("input.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(repeating: 65, count: 32).write(to: file)

        XCTAssertThrowsError(try AppleBoundedFile.readData(atPath: file.path, maximumSize: 16)) { error in
            XCTAssertEqual(error as? AppleBoundedFileError, .tooLarge)
        }
    }

    func testRejectsDirectoriesAndSymlinks() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-bounded-file-\(UUID().uuidString)")
        let file = directory.appendingPathComponent("input.json")
        let link = directory.appendingPathComponent("link.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: file)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)

        XCTAssertThrowsError(try AppleBoundedFile.readData(atPath: directory.path, maximumSize: 16)) { error in
            XCTAssertEqual(error as? AppleBoundedFileError, .notRegular)
        }
        XCTAssertThrowsError(try AppleBoundedFile.readData(atPath: link.path, maximumSize: 16)) { error in
            XCTAssertEqual(error as? AppleBoundedFileError, .notRegular)
        }
    }
}
