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
        let macho = try MachOInspector.inspect(path: path)
        guard let slice = macho.slices.first,
              let address = slice.preferredTextAddress else {
            throw XCTSkip("/bin/echo did not expose a selected Mach-O slice")
        }
        let calls = ToolCalls()
        let result = try SymbolicationService.symbolize(
            binaryPath: path,
            architecture: slice.architecture.name,
            address: String(format: "0x%llx", address + 1),
            toolRunner: SymbolicationToolRunner { arguments, _ in
                calls.arguments.append(arguments)
                return SymbolicationToolResult(stdout: "echo (in echo)")
            }
        )
        XCTAssertEqual(result.binaryPath, path)
        XCTAssertEqual(result.status, .resolvedSymbolOnly)
        XCTAssertEqual(calls.arguments.count, 1)
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

        let slice = try MachOInspector.inspect(path: "/bin/echo").slices.first!
        let address = slice.preferredTextAddress! + 1

        let result = try SymbolicationService.symbolize(
            binaryPath: root.path,
            architecture: slice.architecture.name,
            address: String(format: "0x%llx", address),
            toolRunner: SymbolicationToolRunner { _, _ in
                SymbolicationToolResult(stdout: "echo (in Echo) (echo.c:1)")
            }
        )

        XCTAssertEqual(result.binaryPath, root.path)
        XCTAssertEqual(result.status, .resolvedSourceLine)
        XCTAssertEqual(result.sourceLine, 1)
    }

    func testKnownAddressFailuresAndUnrecognizedAtosOutputDoNotClaimSuccess() throws {
        let path = "/bin/echo"
        let slice = try MachOInspector.inspect(path: path).slices.first!
        let calls = ToolCalls()
        let runner = SymbolicationToolRunner { arguments, _ in
            calls.arguments.append(arguments)
            return SymbolicationToolResult(stdout: "not a recognized atos result")
        }
        XCTAssertThrowsError(
            try SymbolicationService.symbolize(
                binaryPath: path,
                architecture: "not-an-architecture",
                address: "0x100000000",
                toolRunner: runner
            )
        )
        XCTAssertThrowsError(
            try SymbolicationService.symbolize(
                binaryPath: path,
                architecture: slice.architecture.name,
                address: "0x0",
                toolRunner: runner
            )
        )
        XCTAssertEqual(calls.arguments.count, 0)

        let result = try SymbolicationService.symbolize(
            binaryPath: path,
            architecture: slice.architecture.name,
            address: String(format: "0x%llx", slice.preferredTextAddress! + 1),
            toolRunner: runner
        )
        XCTAssertEqual(result.status, .unresolved)
        XCTAssertEqual(calls.arguments.count, 1)
    }

    func testAtosPlaceholderWithDecorationsRemainsUnresolved() {
        let output = SymbolicationService.classifyAtosOutput(
            "??? (in Echo) (fixture.c:42)",
            requestedAddress: "0x100000001"
        )
        XCTAssertEqual(output.status, .unresolved)
        XCTAssertNil(output.sourceLine)
    }

    private final class ToolCalls: @unchecked Sendable {
        var arguments: [[String]] = []
    }
}
