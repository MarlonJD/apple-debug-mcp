// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleDyldSharedCacheTests: XCTestCase {
    func testParsesBoundedSyntheticSharedCacheHeaderAndTables() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-dyld-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: url) }
        var data = Data(repeating: 0, count: 512)
        data.replaceSubrange(0..<16, with: Data("dyld_v1  arm64e\0".utf8))
        put32(&data, at: 16, value: 256)
        put32(&data, at: 20, value: 1)
        put32(&data, at: 24, value: 288)
        put32(&data, at: 28, value: 1)
        put64(&data, at: 32, value: 0x180000000)
        put64(&data, at: 40, value: 400)
        put64(&data, at: 48, value: 32)
        put64(&data, at: 72, value: 432)
        put64(&data, at: 80, value: 16)
        for index in 0..<16 { data[88 + index] = UInt8(index + 1) }
        put64(&data, at: 256, value: 0x180000000)
        put64(&data, at: 264, value: 0x1000)
        put64(&data, at: 272, value: 0)
        put32(&data, at: 280, value: 7)
        put32(&data, at: 284, value: 5)
        put64(&data, at: 288, value: 0x180001000)
        put64(&data, at: 296, value: 123)
        put64(&data, at: 304, value: 456)
        put32(&data, at: 312, value: 320)
        data.replaceSubrange(320..<340, with: Data("/usr/lib/libFoo.dylib\0".utf8))
        try data.write(to: url)

        let report = try AppleDyldSharedCacheService.inspect(path: url.path)

        XCTAssertEqual(report.architecture, "arm64e")
        XCTAssertEqual(report.mappingCount, 1)
        XCTAssertEqual(report.imageCount, 1)
        XCTAssertEqual(report.images.first?.path, "/usr/lib/libFoo.dylib")
        XCTAssertEqual(report.mappings.first?.maximumProtection, 7)
        XCTAssertEqual(report.uuid, "01020304-0506-0708-090A-0B0C0D0E0F10")
    }

    func testDiscoveryReportsBoundedRootsAndExplicitCacheNotes() {
        let discovery = AppleDyldSharedCacheService.discover()

        XCTAssertGreaterThanOrEqual(discovery.searchedRoots.count, 4)
        XCTAssertFalse(discovery.notes.isEmpty)
        XCTAssertTrue(discovery.candidates.allSatisfy { $0.hasPrefix("/") })
        XCTAssertTrue(discovery.runtimeHelpers.allSatisfy { $0.hasPrefix("/") })
    }

    private func put32(_ data: inout Data, at offset: Int, value: UInt32) {
        for index in 0..<4 { data[offset + index] = UInt8((value >> UInt32(index * 8)) & 0xff) }
    }

    private func put64(_ data: inout Data, at offset: Int, value: UInt64) {
        for index in 0..<8 { data[offset + index] = UInt8((value >> UInt64(index * 8)) & 0xff) }
    }
}
