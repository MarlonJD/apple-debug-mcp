// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleControlFlowTests: XCTestCase {
    func testBuildsArm64FunctionAndExternalCallGraph() throws {
        let report = try AppleControlFlowService.analyze(path: "/bin/echo", architecture: "arm64e")

        XCTAssertFalse(report.instructions.isEmpty)
        XCTAssertFalse(report.functions.isEmpty)
        XCTAssertTrue(report.functions.contains { !$0.blocks.isEmpty })
        XCTAssertFalse(report.xrefs.isEmpty)
        XCTAssertTrue(report.xrefs.contains { $0.kind == "call" })
    }

    func testParsesMachORelocationEvidence() {
        let output = """
        Relocation information (__TEXT,__text) 1 entries
        address  pcrel length extern type    scattered symbolnum/value
        00000040 True   long   True   BR26    False     _usleep
        """

        let relocations = AppleControlFlowService.parseRelocations(output)

        XCTAssertEqual(relocations.count, 1)
        XCTAssertEqual(relocations.first?.section, "__TEXT,__text")
        XCTAssertEqual(relocations.first?.address, "0x40")
        XCTAssertEqual(relocations.first?.type, "BR26")
        XCTAssertEqual(relocations.first?.symbol, "_usleep")
        XCTAssertEqual(relocations.first?.pcrel, true)
    }
}
