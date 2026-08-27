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

    func testCrashFramesDoNotUseNameOnlyArtifactFallback() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let crashPath = repositoryRoot.appendingPathComponent("Tests/Fixtures/example.crash").path
        let report = try CrashSymbolicationService.symbolize(
            path: crashPath,
            artifacts: [
                CrashSymbolicationArtifact(
                    imageName: "AppleDebugFixture",
                    binaryPath: "/bin/echo",
                    architecture: "arm64e"
                )
            ]
        )

        XCTAssertEqual(report.crash.format, "crash")
        XCTAssertEqual(report.frames.count, 3)
        XCTAssertEqual(report.unmatchedFrameCount, 3)
        XCTAssertTrue(report.frames.allSatisfy { $0.artifactPath == nil })
        XCTAssertTrue(report.frames.allSatisfy { $0.status == .missingImageIdentity })
    }

    func testCrashSymbolicationRequiresAtLeastOneArtifact() {
        XCTAssertThrowsError(
            try CrashSymbolicationService.symbolize(
                path: "/tmp/missing.crash",
                artifacts: []
            )
        ) { error in
            XCTAssertEqual(
                error as? CrashReportError,
                .invalidRequest("Crash symbolication requires between 1 and 32 artifacts.")
            )
        }
    }

    func testTextCrashLimitsConstructedImagesThreadsAndFrames() throws {
        var lines = [
            "Process: Fixture [1]",
            "Triggered by Thread: 0",
            "",
        ]
        for thread in 0..<130 {
            lines.append("Thread \(thread):")
            for frame in 0..<20 {
                lines.append("\(frame) Fixture 0x100000001 function_\(frame)")
            }
            lines.append("")
        }
        lines.append("Binary Images:")
        for image in 0..<300 {
            let base = 0x100000000 + image * 0x1000
            let end = base + 0x800
            let uuid = String(format: "%032x", image + 1)
            lines.append(
                String(format: "0x%llx - 0x%llx Fixture arm64 <%@> /tmp/Fixture-%d", base, end, uuid, image)
            )
        }
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-bounded-crash-\(UUID().uuidString).crash")
        try lines.joined(separator: "\n").write(to: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: path) }

        let report = try CrashReportAnalyzer.inspect(path: path.path)

        XCTAssertEqual(report.observedImageCount, 300)
        XCTAssertEqual(report.images.count, 256)
        XCTAssertEqual(report.observedThreadCount, 130)
        XCTAssertEqual(report.threads.count, 128)
        XCTAssertEqual(report.observedFrameCount, 2_600)
        XCTAssertEqual(report.observedFrameCount, report.threads.reduce(0) { $0 + $1.frames.count } + 552)
        XCTAssertTrue(report.truncated)
        XCTAssertLessThanOrEqual(report.threads.reduce(0) { $0 + $1.frames.count }, 2_048)
    }
}
