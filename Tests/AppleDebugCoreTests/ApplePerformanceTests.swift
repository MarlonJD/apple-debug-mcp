// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class ApplePerformanceTests: XCTestCase {
    func testAnalysisRejectsUnsupportedSchema() {
        XCTAssertThrowsError(
            try ApplePerformanceService.analyze(
                tracePath: "/tmp/example.trace",
                schema: "arbitrary-shell-schema"
            )
        ) { error in
            XCTAssertEqual(error as? ApplePerformanceError, .invalidRequest)
        }
    }

    func testAnalysisReportsMissingTrace() {
        XCTAssertThrowsError(
            try ApplePerformanceService.analyze(tracePath: "/tmp/example.trace")
        ) { error in
            XCTAssertEqual(error as? ApplePerformanceError, .traceNotFound)
        }
    }
}
