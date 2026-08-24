// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class DAPTests: XCTestCase {
    func testDAPFramingRoundTripsAcrossPartialReads() throws {
        let request = DAPMessage(
            seq: 7,
            type: "request",
            command: "initialize",
            arguments: .object([
                "pathFormat": .string("path"),
                "linesStartAt1": .boolean(true)
            ])
        )
        let framed = try DAPFraming.frame(request)
        var buffer = Data()

        buffer.append(framed.prefix(9))
        XCTAssertNil(try DAPFraming.nextMessage(from: &buffer))

        buffer.append(framed.dropFirst(9))
        let decoded = try XCTUnwrap(try DAPFraming.nextMessage(from: &buffer))

        XCTAssertEqual(decoded, request)
        XCTAssertTrue(buffer.isEmpty)
    }

    func testToolchainExposesLLDBDAPPath() {
        XCTAssertNotNil(ToolchainProbe.path(for: "lldb-dap"))
    }

    func testDAPValueSupportsNestedPayloads() throws {
        let value: DAPValue = .object([
            "nested": .array([.integer(1), .boolean(true), .null])
        ])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(DAPValue.self, from: data)

        XCTAssertEqual(decoded, value)
    }
}
