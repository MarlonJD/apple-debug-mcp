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
}
