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

        let unknownTunnel = AppleDeviceSummary(
            identifier: "unknown-tunnel",
            productType: "iPhone17,1",
            platform: "iOS",
            bootState: "booted",
            pairingState: "paired",
            tunnelState: "unknown"
        )
        XCTAssertFalse(unknownTunnel.isAuthorizedForDevelopment)
    }

    func testParsesLegacyXcodeInventoryWithoutClaimingCoreDeviceTunnel() throws {
        let json = """
        [
          {
            "ignored": false,
            "modelCode": "iPod9,1",
            "simulator": false,
            "modelName": "iPod touch (7th generation)",
            "operatingSystemVersion": "15.8.8",
            "identifier": "be3091413ece7869d08367bf2985276a1e125390",
            "platform": "com.apple.platform.iphoneos",
            "architecture": "arm64",
            "interface": "usb",
            "available": true,
            "name": "FF iPod touch"
          }
        ]
        """

        let devices = try AppleDeviceService.parseLegacyInventory(data: Data(json.utf8))

        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices.first?.transport, .legacyXcode)
        XCTAssertTrue(devices.first?.isAuthorizedForDevelopment == true)
        XCTAssertEqual(devices.first?.tunnelState, "not-required")
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

    func testDeviceActionResultRoundTripsProcessIdentifier() throws {
        let result = AppleDeviceActionResult(
            action: "launch",
            identifier: "02329A9F-84C9-5499-9EBF-074EFCB45F7C",
            output: "launched",
            processID: 1234
        )

        let decoded = try JSONDecoder().decode(
            AppleDeviceActionResult.self,
            from: JSONEncoder().encode(result)
        )

        XCTAssertEqual(decoded, result)
    }
}
