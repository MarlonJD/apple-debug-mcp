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

    func testSymbolicatesDSYMBundlePayload() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-symbolication-\(UUID().uuidString).dSYM")
        let dwarfDirectory = root.appendingPathComponent("Contents/Resources/DWARF")
        try FileManager.default.createDirectory(at: dwarfDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.copyItem(
            atPath: "/bin/echo",
            toPath: dwarfDirectory.appendingPathComponent("Echo").path
        )

        let result = try SymbolicationService.symbolize(
            binaryPath: root.path,
            architecture: "arm64e",
            address: "0x0"
        )

        XCTAssertEqual(result.binaryPath, root.path)
        XCTAssertFalse(result.symbol.isEmpty)
    }
}
