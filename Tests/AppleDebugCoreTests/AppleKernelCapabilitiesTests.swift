// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleKernelCapabilitiesTests: XCTestCase {
    func testKernelBoundaryFailsClosed() {
        let report = AppleKernelCapabilityService.report()

        XCTAssertFalse(report.kernelTaskAttachSupported)
        XCTAssertFalse(report.kernelMemoryReadSupported)
        XCTAssertFalse(report.kernelMemoryWriteSupported)
        XCTAssertFalse(report.kextDebuggingSupported)
        XCTAssertTrue(report.userProcessMemoryMapSupported)
        XCTAssertTrue(report.supportedAlternatives.contains("apple_debug_runtime_diagnose"))
    }
}
