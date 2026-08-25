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

    func testPhysicalDeviceSupportAndRestrictionsAreExplicit() {
        let report = try? XCTUnwrap(
            CapabilityMatrix.reports().first { $0.platform == .iOSDevice }
        )

        XCTAssertTrue(report?.supported.contains(.attach) == true)
        XCTAssertTrue(report?.supported.contains(.memoryWrite) == true)
        XCTAssertTrue(report?.supported.contains(.performanceAnalysis) == true)
        XCTAssertTrue(report?.restricted.contains(.uiInspection) == true)
        XCTAssertTrue(report?.restricted.contains(.logs) == true)
        XCTAssertTrue(report?.notes.contains {
            $0.localizedCaseInsensitiveContains("App Store")
        } == true)
    }

    func testSimulatorUIInspectionIsSupported() throws {
        let report = try XCTUnwrap(
            CapabilityMatrix.reports().first { $0.platform == .iOSSimulator }
        )

        XCTAssertTrue(report.supported.contains(.uiInspection))
        XCTAssertFalse(report.restricted.contains(.uiInspection))
    }

    func testToolchainProbeUsesAnAllowlistedToolSet() {
        let status = ToolchainProbe.collect()
        let names = status.tools.map(\.name)

        XCTAssertEqual(
            names,
            [
                "lldb", "lldb-dap", "simctl", "devicectl", "xcdevice", "ios-deploy", "xcodebuild",
                "codesign", "otool", "nm", "dyld_info", "swiftc", "swift-demangle", "dwarfdump", "vmmap", "xctrace",
                "heap", "leaks", "malloc_history", "sample", "clang", "llvm-objdump"
            ]
        )
    }
}
