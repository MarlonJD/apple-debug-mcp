// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleRuntimeDiagnosticsTests: XCTestCase {
    func testRequiresAttachGrant() {
        XCTAssertThrowsError(
            try RuntimeDiagnosticsService.inspect(
                processID: 1,
                tool: .heap
            )
        ) { error in
            XCTAssertEqual(error as? RuntimeDiagnosticError, .permissionDisabled)
        }
    }

    func testPolicyGatePrecedesModeValidation() {
        XCTAssertThrowsError(
            try RuntimeDiagnosticsService.inspect(
                processID: 1,
                tool: .heap,
                mode: "arbitrary"
            )
        ) { error in
            XCTAssertEqual(error as? RuntimeDiagnosticError, .permissionDisabled)
        }
    }
}
