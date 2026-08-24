// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleSimulatorTests: XCTestCase {
    func testListsAvailableSimulatorsWithoutMutatingState() throws {
        let devices = try SimulatorService.list()

        XCTAssertFalse(devices.isEmpty)
        XCTAssertTrue(devices.allSatisfy { !$0.udid.isEmpty && !$0.runtime.isEmpty })
    }

    func testMutationIsDisabledByDefault() {
        XCTAssertThrowsError(
            try SimulatorService.boot(udid: "00000000-0000-0000-0000-000000000000")
        ) { error in
            XCTAssertEqual(error as? SimulatorError, .mutationDisabled)
        }
    }

    func testExtendedSimulatorControlsArePolicyGated() {
        XCTAssertThrowsError(
            try SimulatorService.setLocation(
                udid: "00000000-0000-0000-0000-000000000000",
                latitude: 37.0,
                longitude: -122.0
            )
        ) { error in
            XCTAssertEqual(error as? SimulatorError, .mutationDisabled)
        }
        XCTAssertThrowsError(
            try SimulatorService.recordVideo(
                udid: "00000000-0000-0000-0000-000000000000",
                path: "/tmp/apple-debug-mcp-test.mov",
                durationSeconds: 1
            )
        ) { error in
            XCTAssertEqual(error as? SimulatorError, .mutationDisabled)
        }
    }

    func testScreenshotIsDisabledByDefault() {
        XCTAssertThrowsError(
            try SimulatorService.screenshot(udid: "00000000-0000-0000-0000-000000000000")
        ) { error in
            XCTAssertEqual(error as? SimulatorError, .mutationDisabled)
        }
    }

    func testLaunchRejectsUnsafeArguments() {
        XCTAssertThrowsError(
            try SimulatorService.launch(
                udid: "00000000-0000-0000-0000-000000000000",
                bundleID: "com.example.fixture",
                arguments: [String(repeating: "x", count: 4097)]
            )
        ) { error in
            XCTAssertEqual(error as? SimulatorError, .invalidLaunchArguments)
        }
    }

    func testAppInfoRejectsUnknownSimulator() {
        XCTAssertThrowsError(
            try SimulatorService.appInfo(
                udid: "00000000-0000-0000-0000-000000000000",
                bundleID: "com.example.fixture"
            )
        ) { error in
            XCTAssertEqual(
                error as? SimulatorError,
                .unknownDevice("00000000-0000-0000-0000-000000000000")
            )
        }
    }
}
