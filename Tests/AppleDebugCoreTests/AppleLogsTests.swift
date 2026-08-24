// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleLogsTests: XCTestCase {
    func testRejectsUnboundedDurationBeforeRunningTooling() {
        XCTAssertThrowsError(
            try AppleLogService.show(target: "host", last: "forever")
        ) { error in
            XCTAssertEqual(error as? AppleLogError, .invalidDuration)
        }
    }

    func testRejectsMultilinePredicate() {
        XCTAssertThrowsError(
            try AppleLogService.show(target: "host", last: "1s", predicate: "process == 'fixture'\nOR true")
        ) { error in
            XCTAssertEqual(error as? AppleLogError, .invalidPredicate)
        }
    }

    func testRejectsUnknownSimulatorBeforeRunningTooling() {
        XCTAssertThrowsError(
            try AppleLogService.show(
                target: "00000000-0000-0000-0000-000000000000",
                last: "1s"
            )
        ) { error in
            XCTAssertEqual(
                error as? AppleLogError,
                .targetNotFound("00000000-0000-0000-0000-000000000000")
            )
        }
    }
}
