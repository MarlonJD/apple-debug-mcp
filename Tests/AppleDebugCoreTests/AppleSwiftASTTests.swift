// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleSwiftASTTests: XCTestCase {
    func testDumpsTypedPublicSwiftASTFromFixtureSource() throws {
        let report = try SwiftASTService.inspect(
            path: "\(FileManager.default.currentDirectoryPath)/Tests/Fixtures/iOSDebugApp/DebugApp.swift",
            moduleName: "DebugApp"
        )

        XCTAssertGreaterThan(report.nodeCount, 0)
        XCTAssertTrue(report.types.contains("DebugApp"))
        XCTAssertTrue(report.nodes.contains { $0.kind == "struct_decl" && $0.name == "DebugApp" })
        XCTAssertTrue(report.imports.contains("SwiftUI"))
        XCTAssertTrue(report.nodes.contains { $0.type?.contains("DebugApp.Type") == true })
        XCTAssertNil(report.rawAST)
    }

    func testRejectsNonSwiftInputBeforeToolInvocation() {
        XCTAssertThrowsError(try SwiftASTService.inspect(path: "/bin/echo")) { error in
            XCTAssertEqual(error as? SwiftASTError, .invalidRequest)
        }
    }
}
