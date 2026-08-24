// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class MachOTests: XCTestCase {
    func testInspectSystemMachO() throws {
        let report = try MachOInspector.inspect(path: "/bin/echo")

        XCTAssertTrue(report.format.contains("Universal Mach-O"))
        XCTAssertFalse(report.architectures.isEmpty)
        XCTAssertTrue(report.segments.isEmpty)

        let thinPath = try XCTUnwrap(ToolchainProbe.path(for: "lldb-dap"))
        let thinReport = try MachOInspector.inspect(path: thinPath)
        XCTAssertEqual(thinReport.format, "Mach-O 64")
        XCTAssertTrue(thinReport.segments.contains { $0.name == "__TEXT" })
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
