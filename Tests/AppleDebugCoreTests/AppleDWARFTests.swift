// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleDWARFTests: XCTestCase {
    func testMissingInputIsTyped() {
        XCTAssertThrowsError(
            try DWARFService.inspect(path: "/tmp/apple-debug-mcp-missing-dsym")
        ) { error in
            XCTAssertEqual(error as? DWARFError, .inputNotFound)
        }
    }

    func testRejectsUnboundedQuery() {
        XCTAssertThrowsError(
            try DWARFService.inspect(path: "/bin/echo", depth: 9)
        ) { error in
            XCTAssertEqual(error as? DWARFError, .invalidRequest)
        }
    }
}
