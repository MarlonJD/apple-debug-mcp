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
}
