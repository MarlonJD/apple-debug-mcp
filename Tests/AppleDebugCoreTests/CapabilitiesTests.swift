// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class CapabilitiesTests: XCTestCase {
    func testCapabilityMatrixCoversAllAppleTargets() {
        let reports = CapabilityMatrix.reports()

        XCTAssertEqual(
            Set(reports.map(\.platform)),
            Set(AppleDebugPlatform.allCases)
        )
    }

    func testPhysicalDeviceRestrictionsAreExplicit() {
        let report = try? XCTUnwrap(
            CapabilityMatrix.reports().first { $0.platform == .iOSDevice }
        )

        XCTAssertTrue(report?.restricted.contains(.attach) == true)
        XCTAssertTrue(report?.restricted.contains(.memoryWrite) == true)
        XCTAssertTrue(report?.notes.contains {
            $0.localizedCaseInsensitiveContains("App Store")
        } == true)
    }

    func testToolchainProbeUsesAnAllowlistedToolSet() {
        let status = ToolchainProbe.collect()
        let names = status.tools.map(\.name)

        XCTAssertEqual(
            names,
            ["lldb", "lldb-dap", "simctl", "devicectl", "xcodebuild"]
        )
    }
}
