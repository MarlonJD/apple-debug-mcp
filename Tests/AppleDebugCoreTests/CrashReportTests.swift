// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class CrashReportTests: XCTestCase {
    func testParsesTextCrashReportFixture() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let path = repositoryRoot.appendingPathComponent("Tests/Fixtures/example.crash").path

        let report = try CrashReportAnalyzer.inspect(path: path)

        XCTAssertEqual(report.format, "crash")
        XCTAssertEqual(report.processName, "AppleDebugFixture")
        XCTAssertEqual(report.processID, 4242)
        XCTAssertEqual(report.bundleIdentifier, "com.burakkarahan.AppleDebugFixture")
        XCTAssertEqual(report.exceptionType, "EXC_BAD_ACCESS (SIGSEGV)")
        XCTAssertEqual(report.crashedThread, 0)
        XCTAssertEqual(report.threads.count, 2)
        XCTAssertEqual(report.threads.first?.frames.count, 2)
    }

    func testRejectsUnknownCrashReportFormat() {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: path) }
        try? Data("not a crash report".utf8).write(to: path)

        XCTAssertThrowsError(try CrashReportAnalyzer.inspect(path: path.path)) { error in
            XCTAssertEqual(error as? CrashReportError, .unsupportedFormat)
        }
    }

    func testParsesIPSJSONReport() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-(UUID().uuidString).ips")
        defer { try? FileManager.default.removeItem(at: path) }
        let json = """
        {
          "name": "DebugApp",
          "bundleID": "com.burakkarahan.AppleDebugFixture",
          "pid": 77,
          "faultingThread": 0,
          "exception": {"type": "EXC_CRASH", "signal": "SIGABRT"},
          "threads": [
            {"id": 0, "triggered": true, "frames": [{"image": "DebugApp", "symbol": "main", "address": "0x1000"}]}
          ],
          "usedImages": [
            {"name": "DebugApp", "uuid": "ABC", "path": "/tmp/DebugApp", "base": "0x1000"}
          ]
        }
        """
        try Data(json.utf8).write(to: path)

        let report = try CrashReportAnalyzer.inspect(path: path.path)

        XCTAssertEqual(report.format, "ips")
        XCTAssertEqual(report.processName, "DebugApp")
        XCTAssertEqual(report.processID, 77)
        XCTAssertEqual(report.signal, "SIGABRT")
        XCTAssertEqual(report.threads.first?.frames.first?.symbol, "main")
        XCTAssertEqual(report.images.first?.uuid, "ABC")
    }
}
