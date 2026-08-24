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

    func testDumpsBoundedMultiFileSwiftModuleAST() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("apple-debug-mcp-swift-ast-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appendingPathComponent("First.swift")
        let second = directory.appendingPathComponent("Second.swift")
        try "struct First { let value: Int }\n".write(to: first, atomically: true, encoding: .utf8)
        try "enum Second { case value }\n".write(to: second, atomically: true, encoding: .utf8)

        let report = try SwiftASTService.inspect(paths: [first.path, second.path], moduleName: "MultiSource")

        XCTAssertEqual(report.sourcePaths, [first.path, second.path])
        XCTAssertTrue(report.types.contains("First"))
        XCTAssertTrue(report.types.contains("Second"))
        XCTAssertTrue(report.notes.contains { $0.contains("multi-file") })
    }

    func testDumpsXcodeTargetModuleASTWithSDKContext() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectPath = repositoryRoot
            .appendingPathComponent("Tests/Fixtures/iOSDebugApp/DebugApp.xcodeproj")
            .path

        let report = try SwiftASTService.inspect(
            projectPath: projectPath,
            scheme: "DebugApp",
            configuration: "Debug",
            destination: "generic/platform=iOS Simulator"
        )

        XCTAssertEqual(report.projectPath, projectPath)
        XCTAssertEqual(report.scheme, "DebugApp")
        XCTAssertEqual(report.targetName, "DebugApp")
        XCTAssertEqual(report.moduleName, "DebugApp")
        XCTAssertTrue(report.types.contains("DebugApp"))
        XCTAssertEqual(report.sourcePaths.count, 1)
    }
}
