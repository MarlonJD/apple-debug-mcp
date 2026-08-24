// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleBinaryIntelligenceTests: XCTestCase {
    func testInspectsSignedUniversalAppleBinary() throws {
        let report = try AppleBinaryIntelligenceService.inspect(path: "/bin/echo")

        XCTAssertEqual(report.path, "/bin/echo")
        XCTAssertTrue(report.codeSignature.signed)
        XCTAssertEqual(report.codeSignature.metadata["Identifier"], "com.apple.echo")
        XCTAssertTrue(report.linkedLibraries.contains("/usr/lib/libSystem.B.dylib"))
        XCTAssertTrue(report.symbols.contains { $0.name == "_exit" && $0.undefined })
        XCTAssertTrue(report.dyldExports.contains { $0.symbol == "__mh_execute_header" })
    }

    func testRejectsUnknownArchitecture() {
        XCTAssertThrowsError(
            try AppleBinaryIntelligenceService.inspect(
                path: "/bin/echo",
                architecture: "mips64"
            )
        ) { error in
            XCTAssertEqual(error as? AppleBinaryError, .invalidArchitecture)
        }
    }
}
