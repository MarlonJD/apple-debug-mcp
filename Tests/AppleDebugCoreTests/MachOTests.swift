// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class MachOTests: XCTestCase {
    func testInspectSystemMachO() throws {
        let report = try MachOInspector.inspect(path: "/bin/echo")

        XCTAssertTrue(report.format.contains("Mach-O"))
        if report.format.contains("Universal Mach-O") {
            XCTAssertFalse(report.architectures.isEmpty)
            XCTAssertTrue(report.segments.isEmpty)
        } else {
            XCTAssertTrue(report.format.contains("64"))
            XCTAssertFalse(report.segments.isEmpty)
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-macho-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let thinPath = directory.appendingPathComponent("echo-x86_64")
        let lipoResult = try AppleProcessRunner.run(
            executable: "/usr/bin/lipo",
            arguments: ["-thin", "x86_64", "/bin/echo", "-output", thinPath.path],
            maximumOutputSize: 64 * 1024
        )
        XCTAssertEqual(lipoResult.terminationStatus, 0, String(data: lipoResult.stderr, encoding: .utf8) ?? "")

        let thinReport = try MachOInspector.inspect(path: thinPath.path)
        XCTAssertEqual(thinReport.format, "Mach-O 64")
        XCTAssertTrue(thinReport.segments.contains { $0.name == "__TEXT" })
        XCTAssertFalse(thinReport.strings.isEmpty)
    }

    func testRejectsNonMachOInput() {
        let path = "/tmp/apple-debug-mcp-not-macho.txt"
        FileManager.default.createFile(
            atPath: path,
            contents: Data("not a Mach-O".utf8)
        )
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertThrowsError(try MachOInspector.inspect(path: path)) { error in
            XCTAssertEqual(error as? MachOError, .unsupportedFormat)
        }
    }
}
