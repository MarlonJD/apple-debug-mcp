// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleSimulatorUITests: XCTestCase {
    func testUISnapshotRequiresExplicitMutationPolicy() {
        XCTAssertThrowsError(
            try SimulatorUIService.snapshot(
                udid: "00000000-0000-0000-0000-000000000000",
                bundleID: "com.example.fixture",
                projectPath: "/tmp/DebugApp.xcodeproj",
                scheme: "DebugApp"
            )
        ) { error in
            XCTAssertEqual(error as? SimulatorUIError, .mutationDisabled)
        }
    }

    func testInstalledAppProbeRequiresExplicitMutationPolicy() {
        XCTAssertThrowsError(
            try SimulatorUIService.installedAppSnapshot(
                udid: "00000000-0000-0000-0000-000000000000",
                bundleID: "com.example.fixture"
            )
        ) { error in
            XCTAssertEqual(error as? SimulatorUIError, .mutationDisabled)
        }
    }

    func testCoordinateActionRejectsOutOfBoundsNormalizedValues() {
        XCTAssertThrowsError(
            try SimulatorUIService.performAction(
                udid: "00000000-0000-0000-0000-000000000000",
                bundleID: "com.example.fixture",
                projectPath: "/tmp/DebugApp.xcodeproj",
                scheme: "DebugApp",
                action: SimulatorUIActionRequest(action: "coordinateTap", x: 1.1, y: 0.5)
            )
        ) { error in
            XCTAssertEqual(error as? SimulatorUIError, .invalidAction)
        }
    }
}
