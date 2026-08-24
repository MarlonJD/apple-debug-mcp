// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleReverseExecutionTests: XCTestCase {
    func testCurrentAppleLLDBBoundaryIsExplicit() {
        let report = ReverseExecutionService.capabilities()

        XCTAssertFalse(report.processRecordSupported)
        XCTAssertFalse(report.reverseStepSupported)
        XCTAssertFalse(report.reverseContinueSupported)
        XCTAssertFalse(report.timeTravelSupported)
        XCTAssertTrue(report.forwardStopTraceAvailable)
        XCTAssertFalse(report.notes.isEmpty)
    }
}
