// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
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

    func testDAPFramingRejectsOversizedHeaders() {
        var buffer = Data(repeating: 65, count: DAPFraming.maximumHeaderSize + 1)

        XCTAssertThrowsError(try DAPFraming.nextMessage(from: &buffer)) { error in
            XCTAssertEqual(error as? DAPError, .messageTooLarge)
        }
    }

    func testDAPFramingRejectsOversizedBodies() {
        var buffer = Data("Content-Length: \(DAPFraming.maximumBodySize + 1)\r\n\r\n".utf8)

        XCTAssertThrowsError(try DAPFraming.nextMessage(from: &buffer)) { error in
            XCTAssertEqual(error as? DAPError, .messageTooLarge)
        }
    }

    func testDAPFramingRejectsNegativeContentLength() {
        var buffer = Data("Content-Length: -1\r\n\r\n".utf8)

        XCTAssertThrowsError(try DAPFraming.nextMessage(from: &buffer)) { error in
            XCTAssertEqual(error as? DAPError, .invalidContentLength)
        }
    }

    func testSessionFailsClosedWhenEventBufferOverflows() async throws {
        let script = try makeExecutableScript(contents: #"""
#!/usr/bin/env python3
import json
import sys

def frame(message):
    body = json.dumps(message, separators=(",", ":")).encode()
    return f"Content-Length: {len(body)}\r\n\r\n".encode() + body

for index in range(4100):
    sys.stdout.buffer.write(frame({"seq": index + 1, "type": "event", "event": "output", "body": {}}))
sys.stdout.buffer.write(frame({"seq": 5000, "type": "response", "request_seq": 1, "success": True, "command": "initialize"}))
sys.stdout.buffer.flush()
"""#)
        defer { try? FileManager.default.removeItem(at: script) }
        let session = try LLDBDAPSession(executablePath: script.path)

        do {
            _ = try await session.start()
            XCTFail("The event buffer unexpectedly accepted an unbounded stream")
        } catch {
            XCTAssertEqual(error as? DAPError, .eventBufferOverflow)
        }
        await session.stop()
    }

    func testSessionFailsClosedWhenStderrOverflows() async throws {
        let script = try makeExecutableScript(contents: #"""
#!/usr/bin/env python3
import sys
import time

sys.stderr.write("x" * (1024 * 1024 + 1))
sys.stderr.flush()
time.sleep(5)
"""#)
        defer { try? FileManager.default.removeItem(at: script) }
        let session = try LLDBDAPSession(executablePath: script.path)

        do {
            _ = try await session.start()
            XCTFail("The stderr buffer unexpectedly accepted unbounded diagnostics")
        } catch {
            XCTAssertEqual(error as? DAPError, .stderrTooLarge)
        }
        await session.stop()
    }

    private func makeExecutableScript(contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-dap-test-\(UUID().uuidString).py")
        let script = contents.hasPrefix("\n") ? String(contents.dropFirst()) : contents
        try Data(script.utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }
}
