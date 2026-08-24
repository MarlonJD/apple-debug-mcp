// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleBinaryDiffTests: XCTestCase {
    func testIdenticalBinaryDiffIsClean() throws {
        let report = try AppleBinaryDiffService.diff(
            leftPath: "/bin/echo",
            rightPath: "/bin/echo"
        )

        XCTAssertFalse(report.changed)
        XCTAssertFalse(report.binaryChanged)
        XCTAssertTrue(report.architecturesAdded.isEmpty)
        XCTAssertTrue(report.addedSymbols.isEmpty)
        XCTAssertTrue(report.changedExports.isEmpty)
    }

    func testAppAndDSYMBundlesResolveToBoundedArtifactDescriptors() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-diff-\(UUID().uuidString)")
        let app = root.appendingPathComponent("Demo.app")
        let appExecutable = app.appendingPathComponent("Demo")
        let dSYM = root.appendingPathComponent("Demo.app.dSYM")
        let dwarfDirectory = dSYM.appendingPathComponent("Contents/Resources/DWARF")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dwarfDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let plist: [String: Any] = [
            "CFBundleExecutable": "Demo",
            "CFBundleIdentifier": "com.example.demo",
            "CFBundleVersion": "7",
            "CFBundleShortVersionString": "1.2"
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: app.appendingPathComponent("Info.plist"))
        try FileManager.default.copyItem(atPath: "/bin/echo", toPath: appExecutable.path)
        try FileManager.default.copyItem(atPath: "/bin/echo", toPath: dwarfDirectory.appendingPathComponent("Demo").path)

        let report = try AppleBinaryDiffService.diff(leftPath: app.path, rightPath: dSYM.path)

        XCTAssertEqual(report.left.kind, .app)
        XCTAssertEqual(report.right.kind, .dSYM)
        XCTAssertEqual(report.left.bundleIdentifier, "com.example.demo")
        XCTAssertEqual(report.left.bundleVersion, "7")
        XCTAssertFalse(report.left.executablePath.isEmpty)
        XCTAssertFalse(report.right.uuids.isEmpty)
        XCTAssertTrue(report.changed)
        XCTAssertTrue(report.bundleMetadataChanged)
    }

    func testUnknownDirectoryIsRejected() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-unknown-\(UUID().uuidString)")
        XCTAssertNoThrow(try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true))
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertThrowsError(
            try AppleBinaryDiffService.diff(leftPath: directory.path, rightPath: "/bin/echo")
        ) { error in
            XCTAssertEqual(error as? AppleBinaryDiffError, .unsupportedArtifact)
        }
    }
}
