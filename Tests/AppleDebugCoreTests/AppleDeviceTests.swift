// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleDeviceTests: XCTestCase {
    func testParsesAuthorizedAndUnavailableDeviceStates() throws {
        let json = """
        {
          "result": {
            "devices": [
              {
                "identifier": "paired-device",
                "hardwareProperties": {"productType": "iPhone17,1", "platform": "iOS"},
                "deviceProperties": {"bootState": "booted"},
                "connectionProperties": {"pairingState": "paired", "tunnelState": "connected"}
              },
              {
                "identifier": "offline-device",
                "hardwareProperties": {"productType": "iPod9,1", "platform": "iOS"},
                "deviceProperties": {"bootState": "booted"},
                "connectionProperties": {"pairingState": "unsupported", "tunnelState": "unavailable"}
              }
            ]
          }
        }
        """

        let devices = try AppleDeviceService.parseInventory(data: Data(json.utf8))

        XCTAssertEqual(devices.count, 2)
        XCTAssertTrue(devices.first { $0.identifier == "paired-device" }?.isAuthorizedForDevelopment == true)
        XCTAssertTrue(devices.first { $0.identifier == "offline-device" }?.isAuthorizedForDevelopment == false)
    }

    func testMutationIsDisabledBeforeDeviceAuthorization() {
        XCTAssertThrowsError(
            try AppleDeviceService.install(
                identifier: "offline-device",
                appPath: "/tmp/missing.app"
            )
        ) { error in
            XCTAssertEqual(error as? AppleDeviceError, .mutationDisabled)
        }
    }

    func testPhysicalDebugRejectsNonUUIDIdentifier() {
        XCTAssertThrowsError(
            try AppleDeviceService.validateAuthorizedDevice(identifier: "not-a-device")
        ) { error in
            XCTAssertEqual(error as? AppleDeviceError, .invalidIdentifier)
        }
    }

    func testListsCoreDevicesWithoutClaimingAuthorization() throws {
        let devices = try AppleDeviceService.list()
        XCTAssertTrue(devices.allSatisfy { !$0.identifier.isEmpty })
    }
}
