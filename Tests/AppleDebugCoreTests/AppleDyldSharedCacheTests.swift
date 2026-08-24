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

    func testAnalyzesSelectedImageMachOExportsAndSymbols() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-dyld-image-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: url) }
        let imageBase: UInt64 = 0x180000000
        let imageFileOffset = 0x1000
        var data = Data(repeating: 0, count: 8192)
        data.replaceSubrange(0..<16, with: Data("dyld_v1  arm64e\0".utf8))
        put32(&data, at: 16, value: 256)
        put32(&data, at: 20, value: 1)
        put32(&data, at: 24, value: 288)
        put32(&data, at: 28, value: 1)
        put64(&data, at: 32, value: imageBase)

        put64(&data, at: 256, value: imageBase)
        put64(&data, at: 264, value: 0x4000)
        put64(&data, at: 272, value: 0)
        put32(&data, at: 280, value: 7)
        put32(&data, at: 284, value: 5)
        put64(&data, at: 288, value: imageBase + UInt64(imageFileOffset))
        put64(&data, at: 296, value: 123)
        put64(&data, at: 304, value: 456)
        put32(&data, at: 312, value: 350)
        data.replaceSubrange(350..<(350 + 20), with: Data("/usr/lib/libFoo.dylib\0".utf8))

        let header = imageFileOffset
        put32(&data, at: header, value: 0xfeedfacf)
        put32(&data, at: header + 4, value: 0x0100000c)
        put32(&data, at: header + 8, value: 0)
        put32(&data, at: header + 12, value: 6)
        put32(&data, at: header + 16, value: 4)
        put32(&data, at: header + 20, value: 144)

        let uuidCommand = header + 32
        put32(&data, at: uuidCommand, value: 0x1b)
        put32(&data, at: uuidCommand + 4, value: 24)
        for index in 0..<16 { data[uuidCommand + 8 + index] = UInt8(index + 1) }

        let segmentCommand = uuidCommand + 24
        put32(&data, at: segmentCommand, value: 0x19)
        put32(&data, at: segmentCommand + 4, value: 72)
        data.replaceSubrange((segmentCommand + 8)..<(segmentCommand + 24), with: Data("__TEXT\0\0\0\0\0\0\0\0\0\0".utf8))
        put64(&data, at: segmentCommand + 24, value: imageBase + UInt64(imageFileOffset))
        put64(&data, at: segmentCommand + 32, value: 0x1000)
        put64(&data, at: segmentCommand + 40, value: UInt64(imageFileOffset))
        put64(&data, at: segmentCommand + 48, value: 0x200)
        put32(&data, at: segmentCommand + 56, value: 5)
        put32(&data, at: segmentCommand + 60, value: 5)

        let exportCommand = segmentCommand + 72
        put32(&data, at: exportCommand, value: 0x80000033)
        put32(&data, at: exportCommand + 4, value: 24)
        put32(&data, at: exportCommand + 8, value: 0x1200)
        put32(&data, at: exportCommand + 16, value: 13)

        let symbolCommand = exportCommand + 24
        put32(&data, at: symbolCommand, value: 0x2)
        put32(&data, at: symbolCommand + 4, value: 24)
        put32(&data, at: symbolCommand + 8, value: 0x1300)
        put32(&data, at: symbolCommand + 12, value: 1)
        put32(&data, at: symbolCommand + 16, value: 0x1310)
        put32(&data, at: symbolCommand + 20, value: 6)

        data.replaceSubrange(0x1200..<(0x1200 + 13), with: Data([0, 1, 0x5f, 0x66, 0x6f, 0x6f, 0, 8, 3, 0, 0x80, 0x02, 0]))
        put32(&data, at: 0x1300, value: 1)
        data[0x1304] = 0x0f
        data[0x1305] = 1
        put16(&data, at: 0x1306, value: 0)
        put64(&data, at: 0x1308, value: imageBase + 0x100)
        data.replaceSubrange(0x1310..<(0x1310 + 6), with: Data([0, 0x5f, 0x62, 0x61, 0x72, 0]))
        try data.write(to: url)

        let analysis = try AppleDyldSharedCacheService.analyzeImage(path: url.path, imagePath: "/usr/lib/libFoo.dylib")

        XCTAssertEqual(analysis.magic, "MH_MAGIC_64")
        XCTAssertEqual(analysis.uuid, "01020304-0506-0708-090A-0B0C0D0E0F10")
        XCTAssertEqual(analysis.segments.first?.name, "__TEXT")
        XCTAssertEqual(analysis.exports.first?.name, "_foo")
        XCTAssertEqual(analysis.exports.first?.address, "0x180001100")
        XCTAssertEqual(analysis.symbols.first?.name, "_bar")
    }

    private func put32(_ data: inout Data, at offset: Int, value: UInt32) {
        for index in 0..<4 { data[offset + index] = UInt8((value >> UInt32(index * 8)) & 0xff) }
    }

    private func put16(_ data: inout Data, at offset: Int, value: UInt16) {
        for index in 0..<2 { data[offset + index] = UInt8((value >> UInt16(index * 8)) & 0xff) }
    }

    private func put64(_ data: inout Data, at offset: Int, value: UInt64) {
        for index in 0..<8 { data[offset + index] = UInt8((value >> UInt64(index * 8)) & 0xff) }
    }
}
