// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import XCTest
@testable import AppleDebugCore

final class MachOIdentityTests: XCTestCase {
    func testUUIDNormalizationAndSubtypeSensitiveArchitecture() throws {
        XCTAssertEqual(
            MachOUUID.normalize("12345678123412341234123456789ABC"),
            "12345678-1234-1234-1234-123456789abc"
        )
        XCTAssertEqual(
            MachOUUID.normalize("12345678-1234-1234-1234-123456789ABC"),
            "12345678-1234-1234-1234-123456789abc"
        )
        XCTAssertNil(MachOUUID.normalize("00000000-0000-0000-0000-000000000000"))
        XCTAssertNil(MachOUUID.normalize("<12345678-1234-1234-1234-123456789abc>"))

        let arm64e = try writeMachO(makeThin(cpuType: 0x0100_000c, subtype: 2))
        let x86_64h = try writeMachO(makeThin(cpuType: 0x0100_0007, subtype: 8))
        defer {
            try? FileManager.default.removeItem(at: arm64e)
            try? FileManager.default.removeItem(at: x86_64h)
        }

        XCTAssertEqual(try MachOInspector.inspect(path: arm64e.path).architectures.first?.name, "arm64e")
        XCTAssertEqual(try MachOInspector.inspect(path: x86_64h.path).architectures.first?.name, "x86_64h")
    }

    func testThinFat32Fat64AndSwappedEndianSlicesExposeUUIDs() throws {
        let thin = makeThin()
        let values: [(String, Data)] = [
            ("thin", thin),
            ("fat32", makeFat(slice: thin, is64Bit: false, order: .big)),
            ("fat64", makeFat(slice: thin, is64Bit: true, order: .big)),
            ("swapped-fat32", makeFat(slice: thin, is64Bit: false, order: .little)),
        ]
        var paths: [URL] = []
        defer { paths.forEach { try? FileManager.default.removeItem(at: $0) } }

        for (label, data) in values {
            let path = try writeMachO(data, suffix: label)
            paths.append(path)
            let report = try MachOInspector.inspect(path: path.path)
            XCTAssertEqual(report.architectures.count, 1, label)
            XCTAssertEqual(report.architectures.first?.uuid, "12345678-1234-1234-1234-123456789abc", label)
            XCTAssertEqual(report.uuids, ["12345678-1234-1234-1234-123456789abc"], label)
            XCTAssertEqual(report.identities.first?.architecture, "arm64", label)
            XCTAssertEqual(report.slices.first?.architecture.fileOffset, label == "thin" ? 0 : report.slices.first?.architecture.fileOffset)
        }
    }

    func testMalformedUUIDAndUniversalBoundariesFailClosed() throws {
        let inputs: [(MachOError, Data)] = [
            (.missingUUID, makeThin(includeUUID: false)),
            (.invalidUUID, makeThin(uuid: Data(repeating: 0, count: 16))),
            (.duplicateUUID, makeThin(uuidCount: 2)),
            (.malformedLoadCommand, makeThin(sizeofCommands: 25)),
            (.overlappingSlices, makeFat(slice: makeThin(), secondSlice: makeThin(), overlap: true)),
            (.malformedUniversalBinary, makeFat(slice: makeThin(), entryCPUType: 0x0100_0007)),
        ]
        var paths: [URL] = []
        defer { paths.forEach { try? FileManager.default.removeItem(at: $0) } }

        for (expected, data) in inputs {
            let path = try writeMachO(data)
            paths.append(path)
            XCTAssertThrowsError(try MachOInspector.inspect(path: path.path)) { error in
                XCTAssertEqual(error as? MachOError, expected)
            }
        }
    }

    private enum Endian {
        case little
        case big
    }

    private func makeThin(
        cpuType: UInt32 = 0x0100_000c,
        subtype: UInt32 = 0,
        uuid: Data = Data([18, 52, 86, 120, 18, 52, 18, 52, 18, 52, 18, 52, 86, 120, 154, 188]),
        includeUUID: Bool = true,
        uuidCount: Int = 1,
        sizeofCommands: UInt32? = nil,
        order: Endian = .little
    ) -> Data {
        let commandCount = includeUUID ? uuidCount : 0
        let commandsSize = sizeofCommands ?? UInt32(commandCount * 24)
        var data = Data(repeating: 0, count: 32)
        write32(&data, at: 0, value: 0xfeedfacf, order: order)
        write32(&data, at: 4, value: cpuType, order: order)
        write32(&data, at: 8, value: subtype, order: order)
        write32(&data, at: 12, value: 2, order: order)
        write32(&data, at: 16, value: UInt32(commandCount), order: order)
        write32(&data, at: 20, value: commandsSize, order: order)
        write32(&data, at: 24, value: 0, order: order)
        if includeUUID {
            for _ in 0..<uuidCount {
                let commandOffset = data.count
                write32(&data, at: commandOffset, value: 0x1b, order: order)
                write32(&data, at: commandOffset + 4, value: 24, order: order)
                data.append(uuid)
            }
        }
        return data
    }

    private func makeFat(
        slice: Data,
        secondSlice: Data? = nil,
        is64Bit: Bool = false,
        order: Endian = .big,
        overlap: Bool = false,
        entryCPUType: UInt32 = 0x0100_000c
    ) -> Data {
        let slices = [slice] + (secondSlice.map { [$0] } ?? [])
        let entrySize = is64Bit ? 32 : 20
        let tableEnd = 8 + entrySize * slices.count
        var offsets: [Int] = []
        var cursor = tableEnd
        for (index, value) in slices.enumerated() {
            offsets.append(index == 1 && overlap ? tableEnd : cursor)
            cursor += value.count
        }
        var data = Data(repeating: 0, count: tableEnd)
        write32(&data, at: 0, value: is64Bit ? 0xcafebabf : 0xcafebabe, order: order)
        write32(&data, at: 4, value: UInt32(slices.count), order: order)
        for (index, value) in slices.enumerated() {
            let offset = 8 + index * entrySize
            write32(&data, at: offset, value: index == 0 ? entryCPUType : 0x0100_000c, order: order)
            write32(&data, at: offset + 4, value: 0, order: order)
            if is64Bit {
                write64(&data, at: offset + 8, value: UInt64(offsets[index]), order: order)
                write64(&data, at: offset + 16, value: UInt64(value.count), order: order)
                write32(&data, at: offset + 24, value: 2, order: order)
            } else {
                write32(&data, at: offset + 8, value: UInt32(offsets[index]), order: order)
                write32(&data, at: offset + 12, value: UInt32(value.count), order: order)
                write32(&data, at: offset + 16, value: 2, order: order)
            }
        }
        for (index, value) in slices.enumerated() {
            let offset = offsets[index]
            if data.count < offset { data.append(Data(repeating: 0, count: offset - data.count)) }
            data.append(value)
        }
        return data
    }

    private func writeMachO(_ data: Data, suffix: String = UUID().uuidString) throws -> URL {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-macho-\(suffix)")
        try data.write(to: path)
        return path
    }

    private func write32(_ data: inout Data, at offset: Int, value: UInt32, order: Endian) {
        if data.count < offset + 4 { data.append(Data(repeating: 0, count: offset + 4 - data.count)) }
        let bytes: [UInt8]
        switch order {
        case .little:
            bytes = [UInt8(value & 0xff), UInt8((value >> 8) & 0xff), UInt8((value >> 16) & 0xff), UInt8((value >> 24) & 0xff)]
        case .big:
            bytes = [UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff), UInt8((value >> 8) & 0xff), UInt8(value & 0xff)]
        }
        data.replaceSubrange(offset..<(offset + 4), with: bytes)
    }

    private func write64(_ data: inout Data, at offset: Int, value: UInt64, order: Endian) {
        let low = UInt32(value & 0xffff_ffff)
        let high = UInt32(value >> 32)
        switch order {
        case .little:
            write32(&data, at: offset, value: low, order: order)
            write32(&data, at: offset + 4, value: high, order: order)
        case .big:
            write32(&data, at: offset, value: high, order: order)
            write32(&data, at: offset + 4, value: low, order: order)
        }
    }
}
