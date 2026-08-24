// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class DebugSessionTests: XCTestCase {
    func testTargetLaunchRequiresExplicitPolicy() {
        XCTAssertThrowsError(
            try DebugPolicy.validateLaunchTarget(path: "/bin/echo")
        ) { error in
            XCTAssertEqual(error as? DebugPolicyError, .launchDisabled)
        }
    }

    func testTargetAttachRequiresExplicitPolicy() {
        XCTAssertThrowsError(
            try DebugPolicy.validateAttach(processID: 1)
        ) { error in
            XCTAssertEqual(error as? DebugPolicyError, .attachDisabled)
        }
    }

    func testMemoryWriteRequiresExplicitPolicy() {
        XCTAssertThrowsError(
            try DebugPolicy.validateMemoryWrite(data: Data([0x01]))
        ) { error in
            XCTAssertEqual(error as? DebugPolicyError, .memoryWriteDisabled)
        }
    }

    func testExpressionEvaluationRequiresExplicitPolicy() {
        XCTAssertThrowsError(
            try DebugPolicy.validateEvaluate()
        ) { error in
            XCTAssertEqual(error as? DebugPolicyError, .evaluateDisabled)
        }
    }

    func testManagerCreatesAndClosesDAPSession() async throws {
        let manager = DebugSessionManager()
        let summary = try await manager.create()

        let activeSessions = await manager.list()
        let closed = await manager.close(sessionID: summary.sessionID)
        let remainingSessions = await manager.list()

        XCTAssertEqual(activeSessions.map(\.sessionID), [summary.sessionID])
        XCTAssertTrue(closed)
        XCTAssertTrue(remainingSessions.isEmpty)
    }
}
