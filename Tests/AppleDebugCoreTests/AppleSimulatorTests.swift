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

    func testScreenshotIsDisabledByDefault() {
        XCTAssertThrowsError(
            try SimulatorService.screenshot(udid: "00000000-0000-0000-0000-000000000000")
        ) { error in
            XCTAssertEqual(error as? SimulatorError, .mutationDisabled)
        }
    }
}
