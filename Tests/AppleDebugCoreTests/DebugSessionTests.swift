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

    func testTransactionalMemoryPatchRequiresExplicitPolicy() async {
        let manager = DebugSessionManager()
        do {
            _ = try await manager.patchMemory(
                sessionID: "missing",
                memoryReference: "0x0",
                offset: 0,
                expectedData: nil,
                data: Data([0x01])
            )
            XCTFail("Memory patch unexpectedly bypassed its policy gate")
        } catch {
            XCTAssertEqual(error as? DebugPolicyError, .memoryWriteDisabled)
        }
    }

    func testMemoryWriteRejectsNegativeOffsetBeforeSessionLookup() async {
        let manager = DebugSessionManager()
        do {
            _ = try await manager.writeMemory(
                sessionID: "missing",
                memoryReference: "0x0",
                offset: -1,
                data: Data([0x01])
            )
            XCTFail("Negative memory offset unexpectedly reached the session")
        } catch {
            XCTAssertEqual(error as? DebugPolicyError, .invalidRequest("Memory offset must not be negative."))
        }
    }

    func testVariableWriteRequiresSeparateExplicitPolicy() async {
        let manager = DebugSessionManager()
        do {
            _ = try await manager.setVariable(
                sessionID: "missing",
                variablesReference: 1,
                name: "debug_value",
                value: "8",
                format: nil
            )
            XCTFail("Variable write unexpectedly bypassed its policy gate")
        } catch {
            XCTAssertEqual(error as? DebugPolicyError, .variableWriteDisabled)
        }
    }

    func testStopWaitTimeoutIsBoundedBeforeSessionLookup() async {
        let manager = DebugSessionManager()
        do {
            _ = try await manager.waitForStop(sessionID: "missing", timeoutMilliseconds: 0)
            XCTFail("Zero stop wait timeout unexpectedly reached the session")
        } catch {
            XCTAssertEqual(error as? DebugPolicyError, .invalidRequest("Stop wait timeout must be positive."))
        }
    }

    func testExpressionEvaluationRequiresExplicitPolicy() {
        XCTAssertThrowsError(
            try DebugPolicy.validateEvaluate()
        ) { error in
            XCTAssertEqual(error as? DebugPolicyError, .evaluateDisabled)
        }
    }

    func testPhysicalDebugRequiresExplicitPolicy() async {
        let manager = DebugSessionManager()

        do {
            _ = try await manager.create(deviceIdentifier: "DF79818E-85ED-569D-9FEB-9EA9B03A8766")
            XCTFail("Physical debug session unexpectedly bypassed its policy gate")
        } catch {
            XCTAssertEqual(error as? AppleDeviceError, .debugDisabled)
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
