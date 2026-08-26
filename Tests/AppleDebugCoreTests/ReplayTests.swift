// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class ReplayTests: XCTestCase {
    func testCapabilitiesDistinguishCheckpointReplayFromNativeReverse() {
        let report = ReplayBackendService.capabilities()

        XCTAssertTrue(report.checkpointReplaySupported)
        XCTAssertFalse(report.nativeReverseExecutionSupported)
        XCTAssertFalse(report.externalRecordReplaySupported)
        XCTAssertTrue(report.scope.contains("local macOS"))
    }

    func testCheckpointRoundTripsThroughCodable() throws {
        let frame = DAPMessage(
            type: "response",
            body: .object([
                "stackFrames": .array([
                    .object([
                        "id": .integer(42),
                        "line": .integer(17),
                        "source": .object(["path": .string("/tmp/Fixture.swift")])
                    ])
                ])
            ])
        )
        let snapshot = DebugStopSnapshot(
            sessionID: "session",
            stopReason: "breakpoint",
            stoppedThreadID: 1,
            events: [],
            threads: DAPMessage(type: "response", body: .object(["threads": .array([])])),
            stackTrace: frame,
            scopes: nil,
            registers: nil,
            modules: nil
        )
        let checkpoint = ReplayCheckpoint(
            checkpointID: "checkpoint",
            sessionID: "session",
            createdAt: "2026-08-26T00:00:00Z",
            label: "breakpoint",
            sourcePath: "/tmp/Fixture.swift",
            sourceLine: 17,
            stoppedThreadID: 1,
            snapshot: snapshot,
            memoryCaptures: [
                ReplayMemoryCapture(
                    request: ReplayMemoryCaptureRequest(memoryReference: "0x1000", count: 4),
                    response: DAPMessage(type: "response", body: .object(["data": .string("AQIDBA==")]))
                )
            ],
            determinismManifest: ["seed": "1"]
        )

        let data = try JSONEncoder().encode(checkpoint)
        let decoded = try JSONDecoder().decode(ReplayCheckpoint.self, from: data)
        XCTAssertEqual(decoded, checkpoint)
    }

    func testReplayRejectsRelativeCheckpointPath() async {
        let manager = CheckpointReplayManager(sessions: DebugSessionManager())

        do {
            _ = try await manager.replay(
                sessionID: "missing",
                checkpointPath: "checkpoint.json",
                timeoutMilliseconds: 1_000
            )
            XCTFail("Relative checkpoint path unexpectedly passed validation")
        } catch {
            XCTAssertEqual(error as? ReplayBackendError, .outputPathInvalid)
        }
    }
}
