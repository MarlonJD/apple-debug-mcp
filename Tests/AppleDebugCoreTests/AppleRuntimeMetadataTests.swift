// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleRuntimeMetadataTests: XCTestCase {
    func testExtractsObjectiveCAndSwiftMetadata() throws {
        let report = try AppleRuntimeMetadataService.inspect(path: "/usr/bin/shortcuts")

        XCTAssertFalse(report.objectiveC.classes.isEmpty)
        XCTAssertTrue(report.objectiveC.protocols.contains("NSObject"))
        XCTAssertFalse(report.objectiveC.selectors.isEmpty)
        XCTAssertFalse(report.swift.isEmpty)
        XCTAssertTrue(report.swift.contains { $0.demangled.contains("Foundation") || $0.demangled.contains("Swift") })
    }
}
