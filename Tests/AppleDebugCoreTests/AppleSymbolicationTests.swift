// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleSymbolicationTests: XCTestCase {
    func testRejectsInvalidAddressBeforeRunningAtos() {
        XCTAssertThrowsError(
            try SymbolicationService.symbolize(
                binaryPath: "/bin/echo",
                architecture: "arm64",
                address: "not-an-address"
            )
        ) { error in
            XCTAssertEqual(error as? SymbolicationError, .invalidAddress)
        }
    }

    func testSymbolicatesAUniversalBinary() throws {
        let path = "/bin/echo"
        let result = try SymbolicationService.symbolize(
            binaryPath: path,
            architecture: "arm64e",
            address: "0x0"
        )
        XCTAssertEqual(result.binaryPath, path)
        XCTAssertFalse(result.symbol.isEmpty)
    }
}
