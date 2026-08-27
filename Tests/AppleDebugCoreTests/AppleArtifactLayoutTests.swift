// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import XCTest
@testable import AppleDebugCore

final class AppleArtifactLayoutTests: XCTestCase {
    func testResolverRequiresAbsolutePathsAndRevalidatesRegularIdentity() throws {
        XCTAssertThrowsError(try AppleArtifactLayoutResolver.resolve(path: "relative-macho")) { error in
            XCTAssertEqual(error as? AppleArtifactLayoutError, .invalidPath)
        }
        XCTAssertThrowsError(
            try AppleArtifactLayoutResolver.resolve(
                path: "/" + String(repeating: "a", count: 4_096)
            )
        ) { error in
            XCTAssertEqual(error as? AppleArtifactLayoutError, .invalidPath)
        }
        XCTAssertThrowsError(
            try AppleArtifactLayoutResolver.resolve(
                path: "/bin/echo",
                architecture: String(repeating: "a", count: 65)
            )
        ) { error in
            XCTAssertEqual(error as? AppleArtifactLayoutError, .invalidArchitecture)
        }
        let layout = try AppleArtifactLayoutResolver.resolve(path: "/bin/echo")
        XCTAssertEqual(layout.kind, .binary)
        XCTAssertTrue(layout.resolvedBinaryPath.hasPrefix("/"))
        XCTAssertTrue(AppleArtifactLayoutResolver.revalidate(layout.fileIdentity))
    }

    func testResolverUsesAppMainExecutableAndDirectDSYMPayload() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-layout-\(UUID().uuidString)")
        let app = root.appendingPathComponent("Demo.app")
        let dsym = root.appendingPathComponent("Demo.app.dSYM")
        let dwarf = dsym.appendingPathComponent("Contents/Resources/DWARF")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dwarf, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let plist: [String: Any] = [
            "CFBundleExecutable": "Demo",
            "CFBundleIdentifier": "com.example.demo",
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: app.appendingPathComponent("Info.plist"))
        try FileManager.default.copyItem(atPath: "/bin/echo", toPath: app.appendingPathComponent("Demo").path)
        try FileManager.default.copyItem(atPath: "/bin/echo", toPath: dwarf.appendingPathComponent("Demo").path)

        let appLayout = try AppleArtifactLayoutResolver.resolve(path: app.path)
        XCTAssertEqual(appLayout.kind, .app)
        XCTAssertEqual(appLayout.bundleMetadata["CFBundleExecutable"], "Demo")
        XCTAssertTrue(appLayout.resolvedBinaryPath.hasSuffix("/Demo"))
        let dsymLayout = try AppleArtifactLayoutResolver.resolve(path: dsym.path)
        XCTAssertEqual(dsymLayout.kind, .dSYM)
        XCTAssertTrue(dsymLayout.resolvedBinaryPath.hasSuffix("/DWARF/Demo"))
    }

    func testBundleSymlinkCannotEscapeCanonicalContainment() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-layout-symlink-\(UUID().uuidString).app")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: ["CFBundleExecutable": root.deletingPathExtension().lastPathComponent],
            format: .xml,
            options: 0
        )
        try plistData.write(to: root.appendingPathComponent("Info.plist"))
        try FileManager.default.createSymbolicLink(
            atPath: root.appendingPathComponent(root.deletingPathExtension().lastPathComponent).path,
            withDestinationPath: "/bin/echo"
        )
        XCTAssertThrowsError(try AppleArtifactLayoutResolver.resolve(path: root.path)) { error in
            XCTAssertEqual(error as? AppleArtifactLayoutError, .symlinkEscapesBundle)
        }
    }

    func testDSYMDirectEnumerationStopsAtTheBoundedEntryLimit() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-layout-many-\(UUID().uuidString).dSYM")
        let dwarf = root.appendingPathComponent("Contents/Resources/DWARF")
        try FileManager.default.createDirectory(at: dwarf, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for index in 0...256 {
            FileManager.default.createFile(
                atPath: dwarf.appendingPathComponent("entry-\(index)").path,
                contents: Data("not a Mach-O".utf8)
            )
        }
        XCTAssertThrowsError(try AppleArtifactLayoutResolver.resolve(path: root.path)) { error in
            XCTAssertEqual(error as? AppleArtifactLayoutError, .tooManyDwarfEntries)
        }
    }
}
