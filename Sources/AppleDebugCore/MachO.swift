// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum MachOError: Error, Equatable, LocalizedError, Sendable {
    case fileNotFound
    case notRegularFile
    case fileTooLarge
    case truncated
    case unsupportedFormat
    case malformedLoadCommand

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Mach-O input file was not found."
        case .notRegularFile:
            return "Mach-O input path is not a regular file."
        case .fileTooLarge:
            return "Mach-O input exceeds the configured analysis limit."
        case .truncated:
            return "Mach-O input is truncated."
        case .unsupportedFormat:
            return "Input is not a supported Mach-O or universal Mach-O file."
        case .malformedLoadCommand:
            return "Mach-O contains a malformed load command."
        }
    }
}

public struct MachOArchitecture: Codable, Equatable, Sendable {
    public let cpuType: Int32
    public let cpuSubtype: Int32
    public let fileOffset: UInt64
    public let size: UInt64
    public let alignment: UInt32
    public let name: String

    public init(
        cpuType: Int32,
        cpuSubtype: Int32,
        fileOffset: UInt64,
        size: UInt64,
        alignment: UInt32,
        name: String
    ) {
        self.cpuType = cpuType
        self.cpuSubtype = cpuSubtype
        self.fileOffset = fileOffset
        self.size = size
        self.alignment = alignment
        self.name = name
    }
}

public struct MachOSegment: Codable, Equatable, Sendable {
    public let name: String
    public let virtualAddress: UInt64
    public let virtualSize: UInt64
    public let fileOffset: UInt64
    public let fileSize: UInt64
    public let maxProtection: Int32
    public let initialProtection: Int32
    public let sectionCount: UInt32

    public init(
        name: String,
        virtualAddress: UInt64,
        virtualSize: UInt64,
        fileOffset: UInt64,
        fileSize: UInt64,
        maxProtection: Int32,
        initialProtection: Int32,
        sectionCount: UInt32
    ) {
        self.name = name
        self.virtualAddress = virtualAddress
        self.virtualSize = virtualSize
        self.fileOffset = fileOffset
        self.fileSize = fileSize
        self.maxProtection = maxProtection
        self.initialProtection = initialProtection
        self.sectionCount = sectionCount
    }
}

public struct MachOReport: Codable, Equatable, Sendable {
    public let path: String
    public let format: String
    public let architectures: [MachOArchitecture]
    public let fileType: UInt32?
    public let loadCommandCount: UInt32?
    public let flags: UInt32?
    public let segments: [MachOSegment]

    public init(
        path: String,
        format: String,
        architectures: [MachOArchitecture],
        fileType: UInt32?,
        loadCommandCount: UInt32?,
        flags: UInt32?,
        segments: [MachOSegment]
    ) {
        self.path = path
        self.format = format
        self.architectures = architectures
        self.fileType = fileType
        self.loadCommandCount = loadCommandCount
        self.flags = flags
        self.segments = segments
    }
}

public enum MachOInspector {
    private enum ByteOrder {
        case little
        case big
    }

    private struct Header {
        let order: ByteOrder
        let is64Bit: Bool
        let offset: Int
    }

    private static let maximumFileSize = 128 * 1024 * 1024
    private static let machMagic32: UInt32 = 0xfeedface
    private static let machMagic64: UInt32 = 0xfeedfacf
    private static let machCigam32: UInt32 = 0xcefaedfe
    private static let machCigam64: UInt32 = 0xcffaedfe
    private static let fatMagic: UInt32 = 0xcafebabe
    private static let fatMagic64: UInt32 = 0xcafebabf
    private static let fatCigam: UInt32 = 0xbebafeca
    private static let fatCigam64: UInt32 = 0xbfbafeca
    private static let segmentCommand: UInt32 = 0x1
    private static let segment64Command: UInt32 = 0x19

    public static func inspect(path: String) throws -> MachOReport {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MachOError.fileNotFound
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let type = attributes[.type] as? FileAttributeType, type == .typeRegular else {
            throw MachOError.notRegularFile
        }
        if let size = attributes[.size] as? NSNumber, size.intValue > maximumFileSize {
            throw MachOError.fileTooLarge
        }

        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard let magic = readUInt32(data, at: 0, order: .little) else {
            throw MachOError.truncated
        }

        switch magic {
        case fatMagic:
            return try inspectFat(path: url.path, data: data, order: .little, is64Bit: false)
        case fatCigam:
            return try inspectFat(path: url.path, data: data, order: .big, is64Bit: false)
        case fatMagic64:
            return try inspectFat(path: url.path, data: data, order: .little, is64Bit: true)
        case fatCigam64:
            return try inspectFat(path: url.path, data: data, order: .big, is64Bit: true)
        case machMagic32:
            return try inspectThin(path: url.path, data: data, header: Header(order: .little, is64Bit: false, offset: 0))
        case machMagic64:
            return try inspectThin(path: url.path, data: data, header: Header(order: .little, is64Bit: true, offset: 0))
        case machCigam32:
            return try inspectThin(path: url.path, data: data, header: Header(order: .big, is64Bit: false, offset: 0))
        case machCigam64:
            return try inspectThin(path: url.path, data: data, header: Header(order: .big, is64Bit: true, offset: 0))
        default:
            throw MachOError.unsupportedFormat
        }
    }

    private static func inspectFat(
        path: String,
        data: Data,
        order: ByteOrder,
        is64Bit: Bool
    ) throws -> MachOReport {
        guard let count = readUInt32(data, at: 4, order: order) else {
            throw MachOError.truncated
        }
        let entrySize = is64Bit ? 32 : 20
        let tableStart = 8
        guard Int(count) <= 4096,
              tableStart + (Int(count) * entrySize) <= data.count else {
            throw MachOError.truncated
        }

        var architectures: [MachOArchitecture] = []
        for index in 0..<Int(count) {
            let offset = tableStart + index * entrySize
            guard let cpuType = readInt32(data, at: offset, order: order),
                  let cpuSubtype = readInt32(data, at: offset + 4, order: order),
                  let fileOffset = readUInt32(data, at: offset + 8, order: order),
                  let size = readUInt32(data, at: offset + 12, order: order),
                  let alignment = readUInt32(data, at: offset + 16, order: order) else {
                throw MachOError.truncated
            }
            architectures.append(
                MachOArchitecture(
                    cpuType: cpuType,
                    cpuSubtype: cpuSubtype,
                    fileOffset: UInt64(fileOffset),
                    size: UInt64(size),
                    alignment: alignment,
                    name: architectureName(cpuType)
                )
            )
        }

        return MachOReport(
            path: path,
            format: is64Bit ? "Universal Mach-O 64" : "Universal Mach-O",
            architectures: architectures,
            fileType: nil,
            loadCommandCount: nil,
            flags: nil,
            segments: []
        )
    }

    private static func inspectThin(
        path: String,
        data: Data,
        header: Header
    ) throws -> MachOReport {
        let base = header.offset
        let headerSize = header.is64Bit ? 32 : 28
        guard data.count >= base + headerSize,
              let cpuType = readInt32(data, at: base + 4, order: header.order),
              let cpuSubtype = readInt32(data, at: base + 8, order: header.order),
              let fileType = readUInt32(data, at: base + 12, order: header.order),
              let commandCount = readUInt32(data, at: base + 16, order: header.order),
              let flags = readUInt32(data, at: base + 24, order: header.order) else {
            throw MachOError.truncated
        }

        guard commandCount <= 10000 else {
            throw MachOError.malformedLoadCommand
        }

        var segments: [MachOSegment] = []
        var commandOffset = base + headerSize
        for _ in 0..<Int(commandCount) {
            guard let command = readUInt32(data, at: commandOffset, order: header.order),
                  let commandSize = readUInt32(data, at: commandOffset + 4, order: header.order),
                  commandSize >= 8,
                  commandOffset + Int(commandSize) <= data.count else {
                throw MachOError.malformedLoadCommand
            }

            if command == (header.is64Bit ? segment64Command : segmentCommand) {
                let minimumSize = header.is64Bit ? 72 : 56
                guard Int(commandSize) >= minimumSize else {
                    throw MachOError.malformedLoadCommand
                }
                let segment = try parseSegment(
                    data: data,
                    offset: commandOffset,
                    order: header.order,
                    is64Bit: header.is64Bit
                )
                segments.append(segment)
            }

            commandOffset += Int(commandSize)
        }

        return MachOReport(
            path: path,
            format: header.is64Bit ? "Mach-O 64" : "Mach-O 32",
            architectures: [
                MachOArchitecture(
                    cpuType: cpuType,
                    cpuSubtype: cpuSubtype,
                    fileOffset: 0,
                    size: UInt64(data.count),
                    alignment: 0,
                    name: architectureName(cpuType)
                )
            ],
            fileType: fileType,
            loadCommandCount: commandCount,
            flags: flags,
            segments: segments
        )
    }

    private static func parseSegment(
        data: Data,
        offset: Int,
        order: ByteOrder,
        is64Bit: Bool
    ) throws -> MachOSegment {
        let name = readString(data, at: offset + 8, length: 16)
        if is64Bit {
            guard let virtualAddress = readUInt64(data, at: offset + 24, order: order),
                  let virtualSize = readUInt64(data, at: offset + 32, order: order),
                  let fileOffset = readUInt64(data, at: offset + 40, order: order),
                  let fileSize = readUInt64(data, at: offset + 48, order: order),
                  let maxProtection = readInt32(data, at: offset + 56, order: order),
                  let initialProtection = readInt32(data, at: offset + 60, order: order),
                  let sectionCount = readUInt32(data, at: offset + 64, order: order) else {
                throw MachOError.truncated
            }
            return MachOSegment(
                name: name,
                virtualAddress: virtualAddress,
                virtualSize: virtualSize,
                fileOffset: fileOffset,
                fileSize: fileSize,
                maxProtection: maxProtection,
                initialProtection: initialProtection,
                sectionCount: sectionCount
            )
        }

        guard let virtualAddress = readUInt32(data, at: offset + 24, order: order),
              let virtualSize = readUInt32(data, at: offset + 28, order: order),
              let fileOffset = readUInt32(data, at: offset + 32, order: order),
              let fileSize = readUInt32(data, at: offset + 36, order: order),
              let maxProtection = readInt32(data, at: offset + 40, order: order),
              let initialProtection = readInt32(data, at: offset + 44, order: order),
              let sectionCount = readUInt32(data, at: offset + 48, order: order) else {
            throw MachOError.truncated
        }
        return MachOSegment(
            name: name,
            virtualAddress: UInt64(virtualAddress),
            virtualSize: UInt64(virtualSize),
            fileOffset: UInt64(fileOffset),
            fileSize: UInt64(fileSize),
            maxProtection: maxProtection,
            initialProtection: initialProtection,
            sectionCount: sectionCount
        )
    }

    private static func architectureName(_ cpuType: Int32) -> String {
        switch UInt32(bitPattern: cpuType) {
        case 0x01000007:
            return "x86_64"
        case 0x0100000c:
            return "arm64"
        case 0x00000007:
            return "x86"
        case 0x0000000c:
            return "arm"
        default:
            return "cpu-\(cpuType)"
        }
    }

    private static func readString(_ data: Data, at offset: Int, length: Int) -> String {
        guard offset >= 0, offset + length <= data.count else {
            return ""
        }
        let bytes = data[offset..<(offset + length)]
        let end = bytes.firstIndex(of: 0) ?? bytes.endIndex
        return String(decoding: bytes[..<end], as: UTF8.self)
    }

    private static func readUInt32(_ data: Data, at offset: Int, order: ByteOrder) -> UInt32? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }
        let bytes = data[offset..<(offset + 4)]
        let value = bytes.enumerated().reduce(UInt32(0)) { partial, item in
            let shift = order == .little ? item.offset * 8 : (3 - item.offset) * 8
            return partial | (UInt32(item.element) << UInt32(shift))
        }
        return value
    }

    private static func readInt32(_ data: Data, at offset: Int, order: ByteOrder) -> Int32? {
        guard let value = readUInt32(data, at: offset, order: order) else { return nil }
        return Int32(bitPattern: value)
    }

    private static func readUInt64(_ data: Data, at offset: Int, order: ByteOrder) -> UInt64? {
        guard offset >= 0, offset + 8 <= data.count else { return nil }
        let bytes = data[offset..<(offset + 8)]
        return bytes.enumerated().reduce(UInt64(0)) { partial, item in
            let shift = order == .little ? item.offset * 8 : (7 - item.offset) * 8
            return partial | (UInt64(item.element) << UInt64(shift))
        }
    }
}
