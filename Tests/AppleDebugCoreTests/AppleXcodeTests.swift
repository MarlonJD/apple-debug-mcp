// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleXcodeTests: XCTestCase {
    func testRejectsNonXcodeProjectPath() {
        XCTAssertThrowsError(
            try XcodeService.discover(path: "/bin/echo")
        ) { error in
            XCTAssertEqual(error as? XcodeError, .invalidProjectPath)
        }
    }

    func testBuildIsPolicyGatedBeforeProjectValidation() {
        XCTAssertThrowsError(
            try XcodeService.build(
                path: "/tmp/example.xcodeproj",
                scheme: "Example",
                configuration: "Debug",
                destination: "generic/platform=iOS"
            )
        ) { error in
            XCTAssertEqual(error as? XcodeError, .buildDisabled)
        }
    }

    func testTestExecutionIsPolicyGatedBeforeProjectValidation() {
        XCTAssertThrowsError(
            try XcodeService.test(
                path: "/tmp/example.xcodeproj",
                scheme: "Example",
                configuration: "Debug",
                destination: "generic/platform=iOS Simulator"
            )
        ) { error in
            XCTAssertEqual(error as? XcodeError, .testDisabled)
        }
    }

    func testDefaultResultBundlePathsAreUnique() {
        let first = XcodeService.defaultResultBundleURL()
        let second = XcodeService.defaultResultBundleURL()

        XCTAssertNotEqual(first, second)
        XCTAssertTrue(first.path.hasSuffix(".xcresult"))
        XCTAssertTrue(second.path.hasSuffix(".xcresult"))
    }

    func testDiscoversIOSFixtureProject() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectPath = repositoryRoot
            .appendingPathComponent("Tests/Fixtures/iOSDebugApp/DebugApp.xcodeproj")
            .path

        let result = try XcodeService.discover(path: projectPath)

        XCTAssertEqual(result.kind, "-project")
        if case .object(let description) = result.description {
            XCTAssertNotNil(description["project"])
        } else {
            XCTFail("xcodebuild discovery did not return an object")
        }
    }

    func testResolvesSwiftSourcesAndTargetContextFromIOSFixture() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectPath = repositoryRoot
            .appendingPathComponent("Tests/Fixtures/iOSDebugApp/DebugApp.xcodeproj")
            .path

        let context = try XcodeService.swiftTargetContext(
            path: projectPath,
            scheme: "DebugApp",
            configuration: "Debug",
            destination: "generic/platform=iOS Simulator"
        )

        XCTAssertEqual(context.targetName, "DebugApp")
        XCTAssertEqual(context.moduleName, "DebugApp")
        XCTAssertTrue(context.sourcePaths.contains { $0.hasSuffix("/DebugApp.swift") })
        XCTAssertFalse(context.sourcePaths.contains { $0.hasSuffix("DebugAppUITests.swift") }, "paths=\(context.sourcePaths), notes=\(context.notes)")
        XCTAssertTrue(context.targetTriple?.contains("ios") == true)
        XCTAssertTrue(context.notes.first?.contains("PBX Sources") == true)
    }
}
