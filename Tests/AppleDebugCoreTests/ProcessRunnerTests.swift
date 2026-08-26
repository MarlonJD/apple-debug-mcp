// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import XCTest
@testable import AppleDebugCore

final class ProcessRunnerTests: XCTestCase {
    func testRunsCommandAndReturnsOutput() throws {
        let result = try AppleProcessRunner.run(
            executable: "/bin/sh",
            arguments: ["-c", "printf 'ok'"],
            maximumOutputSize: 1024,
            timeoutMilliseconds: 1_000
        )

        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertEqual(String(decoding: result.stdout, as: UTF8.self), "ok")
    }

    func testUsesFileBackedInputWithoutBlocking() throws {
        let result = try AppleProcessRunner.run(
            executable: "/bin/cat",
            arguments: [],
            maximumOutputSize: 1024,
            timeoutMilliseconds: 1_000,
            input: Data("hello".utf8)
        )

        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertEqual(String(decoding: result.stdout, as: UTF8.self), "hello")
    }

    func testTerminatesACommandThatExceedsItsDeadline() {
        let start = Date()

        XCTAssertThrowsError(
            try AppleProcessRunner.run(
                executable: "/bin/sh",
                arguments: ["-c", "sleep 5"],
                maximumOutputSize: 1024,
                timeoutMilliseconds: 100
            )
        ) { error in
            XCTAssertEqual(error as? AppleProcessRunnerError, .timedOut)
        }

        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    func testStopsACommandWhenOutputExceedsTheLiveLimit() {
        let start = Date()

        XCTAssertThrowsError(
            try AppleProcessRunner.run(
                executable: "/bin/sh",
                arguments: ["-c", "printf '0123456789'; sleep 5"],
                maximumOutputSize: 4,
                timeoutMilliseconds: 2_000
            )
        ) { error in
            XCTAssertEqual(error as? AppleProcessRunnerError, .outputTooLarge)
        }

        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    func testRejectsInvalidExecutionLimits() {
        XCTAssertThrowsError(
            try AppleProcessRunner.run(
                executable: "/bin/echo",
                arguments: [],
                maximumOutputSize: 0
            )
        ) { error in
            XCTAssertEqual(error as? AppleProcessRunnerError, .invalidRequest)
        }
    }
}
