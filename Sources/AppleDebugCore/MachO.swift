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
    case malformedUniversalBinary
    case overlappingSlices
    case malformedLoadCommand
    case missingUUID
    case duplicateUUID
    case invalidUUID
    case invalidArchitecture

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
        case .malformedUniversalBinary:
            return "Universal Mach-O contains an invalid header or slice table."
        case .overlappingSlices:
            return "Universal Mach-O contains overlapping table or slice ranges."
        case .malformedLoadCommand:
            return "Mach-O contains a malformed load command."
        case .missingUUID:
            return "Mach-O slice does not contain exactly one LC_UUID command."
        case .duplicateUUID:
            return "Mach-O slice contains duplicate LC_UUID commands."
        case .invalidUUID:
            return "Mach-O slice contains an invalid or zero LC_UUID value."
        case .invalidArchitecture:
            return "Requested Mach-O architecture is not present."
        }
    }
}

public struct MachOIdentity: Codable, Equatable, Sendable {
    public let uuid: String
    public let architecture: String
    public let cpuType: Int32
    public let cpuSubtype: Int32
    public let sliceOffset: UInt64
    public let sliceSize: UInt64

    public init(
        uuid: String,
        architecture: String,
        cpuType: Int32,
        cpuSubtype: Int32,
        sliceOffset: UInt64,
        sliceSize: UInt64
    ) {
        self.uuid = uuid
        self.architecture = architecture
        self.cpuType = cpuType
        self.cpuSubtype = cpuSubtype
        self.sliceOffset = sliceOffset
        self.sliceSize = sliceSize
    }
}

public struct MachOArchitecture: Codable, Equatable, Sendable {
    public let cpuType: Int32
    public let cpuSubtype: Int32
    public let fileOffset: UInt64
    public let size: UInt64
    public let alignment: UInt32
    public let name: String
    public let uuid: String?
    public let is64Bit: Bool
    public let byteOrder: String

    public init(
        cpuType: Int32,
        cpuSubtype: Int32,
        fileOffset: UInt64,
        size: UInt64,
        alignment: UInt32,
        name: String,
        uuid: String? = nil,
        is64Bit: Bool = false,
        byteOrder: String = "little"
    ) {
        self.cpuType = cpuType
        self.cpuSubtype = cpuSubtype
        self.fileOffset = fileOffset
        self.size = size
        self.alignment = alignment
        self.name = name
        self.uuid = uuid
        self.is64Bit = is64Bit
        self.byteOrder = byteOrder
    }

    public var identity: MachOIdentity? {
        guard let uuid else { return nil }
        return MachOIdentity(
            uuid: uuid,
            architecture: name,
            cpuType: cpuType,
            cpuSubtype: cpuSubtype,
            sliceOffset: fileOffset,
            sliceSize: size
        )
    }

    public var normalizedUUID: String? { uuid }

    public var exactArchitecture: String { name }
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

public struct MachOSymbol: Codable, Equatable, Sendable {
    public let name: String
    public let type: UInt8
    public let section: UInt8
    public let value: UInt64

    public init(name: String, type: UInt8, section: UInt8, value: UInt64) {
        self.name = name
        self.type = type
        self.section = section
        self.value = value
    }
}

public struct MachOSliceReport: Codable, Equatable, Sendable {
    public let path: String
    public let format: String
    public let architecture: MachOArchitecture
    public let fileType: UInt32
    public let loadCommandCount: UInt32
    public let sizeofCommands: UInt32
    public let flags: UInt32
    public let segments: [MachOSegment]
    public let symbols: [MachOSymbol]
    public let strings: [String]

    public init(
        path: String,
        format: String,
        architecture: MachOArchitecture,
        fileType: UInt32,
        loadCommandCount: UInt32,
        sizeofCommands: UInt32 = 0,
        flags: UInt32,
        segments: [MachOSegment],
        symbols: [MachOSymbol] = [],
        strings: [String] = []
    ) {
        self.path = path
        self.format = format
        self.architecture = architecture
        self.fileType = fileType
        self.loadCommandCount = loadCommandCount
        self.sizeofCommands = sizeofCommands
        self.flags = flags
        self.segments = segments
        self.symbols = symbols
        self.strings = strings
    }

    public var uuid: String? { architecture.uuid }

    public var normalizedUUID: String? { architecture.uuid }

    public var exactArchitecture: String { architecture.name }

    public var preferredTextAddress: UInt64? {
        segments.first(where: { $0.name == "__TEXT" })?.virtualAddress
    }

    public var hasEmbeddedDebugInfo: Bool {
        segments.contains(where: { $0.name == "__DWARF" })
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
    public let symbols: [MachOSymbol]
    public let strings: [String]
    public let uuids: [String]
    public let slices: [MachOSliceReport]

    public init(
        path: String,
        format: String,
        architectures: [MachOArchitecture],
        fileType: UInt32?,
        loadCommandCount: UInt32?,
        flags: UInt32?,
        segments: [MachOSegment],
        symbols: [MachOSymbol] = [],
        strings: [String] = [],
        uuids: [String] = [],
        slices: [MachOSliceReport] = []
    ) {
        self.path = path
        self.format = format
        self.architectures = architectures
        self.fileType = fileType
        self.loadCommandCount = loadCommandCount
        self.flags = flags
        self.segments = segments
        self.symbols = symbols
        self.strings = strings
        self.uuids = uuids.isEmpty ? architectures.compactMap(\.uuid) : uuids
        self.slices = slices
    }

    public var identities: [MachOIdentity] {
        architectures.compactMap(\.identity)
    }

    public var sliceReports: [MachOSliceReport] { slices }

    public var uuid: String? { architectures.count == 1 ? architectures.first?.uuid : nil }
}

public enum MachOUUID {
    public static func normalize(_ value: String) -> String? {
        let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let hexDigits: String
        if candidate.count == 32, candidate.allSatisfy({ $0.isHexDigit }) {
            hexDigits = candidate.lowercased()
        } else if candidate.count == 36,
                  candidate.enumerated().allSatisfy({ index, character in
                      [8, 13, 18, 23].contains(index) ? character == "-" : character.isHexDigit
                  }) {
            hexDigits = candidate.replacingOccurrences(of: "-", with: "").lowercased()
        } else {
            return nil
        }
        guard hexDigits.count == 32,
              hexDigits.contains(where: { $0 != "0" }) else {
            return nil
        }
        let starts = [0, 8, 12, 16, 20]
        let lengths = [8, 4, 4, 4, 12]
        return zip(starts, lengths).map { start, length in
            let lower = hexDigits.index(hexDigits.startIndex, offsetBy: start)
            let upper = hexDigits.index(lower, offsetBy: length)
            return String(hexDigits[lower..<upper])
        }.joined(separator: "-")
    }
}

public enum MachOInspector {
    private enum ByteOrder: Equatable {
        case little
        case big

        var name: String { self == .little ? "little" : "big" }
    }

    private struct Header {
        let order: ByteOrder
        let is64Bit: Bool
        let offset: Int
        let limit: Int
    }

    private struct SymbolTable {
        let symbolOffset: Int
        let symbolCount: Int
        let stringOffset: Int
        let stringSize: Int
    }

    private static let maximumFileSize = 128 * 1024 * 1024
    private static let maximumFatSlices = 4096
    private static let maximumLoadCommands = 10_000
    private static let maximumSymbols = 1_000_000
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
    private static let symtabCommand: UInt32 = 0x2
    private static let uuidCommand: UInt32 = 0x1b

    public static func inspect(path: String, architecture: String? = nil) throws -> MachOReport {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MachOError.fileNotFound
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let type = attributes[.type] as? FileAttributeType, type == .typeRegular else {
            throw MachOError.notRegularFile
        }
        if let size = attributes[.size] as? NSNumber, size.int64Value > Int64(maximumFileSize) {
            throw MachOError.fileTooLarge
        }

        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard let magic = readUInt32(data, at: 0, order: .little) else {
            throw MachOError.truncated
        }

        let report: MachOReport
        switch magic {
        case fatMagic:
            report = try inspectFat(path: url.path, data: data, order: .little, is64Bit: false)
        case fatCigam:
            report = try inspectFat(path: url.path, data: data, order: .big, is64Bit: false)
        case fatMagic64:
            report = try inspectFat(path: url.path, data: data, order: .little, is64Bit: true)
        case fatCigam64:
            report = try inspectFat(path: url.path, data: data, order: .big, is64Bit: true)
        case machMagic32:
            report = try inspectThinReport(
                path: url.path,
                data: data,
                header: Header(order: .little, is64Bit: false, offset: 0, limit: data.count),
                fileOffset: 0,
                sliceSize: UInt64(data.count),
                alignment: 0
            )
        case machMagic64:
            report = try inspectThinReport(
                path: url.path,
                data: data,
                header: Header(order: .little, is64Bit: true, offset: 0, limit: data.count),
                fileOffset: 0,
                sliceSize: UInt64(data.count),
                alignment: 0
            )
        case machCigam32:
            report = try inspectThinReport(
                path: url.path,
                data: data,
                header: Header(order: .big, is64Bit: false, offset: 0, limit: data.count),
                fileOffset: 0,
                sliceSize: UInt64(data.count),
                alignment: 0
            )
        case machCigam64:
            report = try inspectThinReport(
                path: url.path,
                data: data,
                header: Header(order: .big, is64Bit: true, offset: 0, limit: data.count),
                fileOffset: 0,
                sliceSize: UInt64(data.count),
                alignment: 0
            )
        default:
            throw MachOError.unsupportedFormat
        }

        if let architecture,
           !report.architectures.contains(where: { $0.name == architecture }) {
            throw MachOError.invalidArchitecture
        }
        return report
    }

    public static func inspectSlice(path: String, architecture: String? = nil) throws -> MachOSliceReport {
        let report = try inspect(path: path, architecture: architecture)
        if let architecture {
            guard let slice = report.slices.first(where: { $0.architecture.name == architecture }) else {
                throw MachOError.invalidArchitecture
            }
            return slice
        }
        guard report.slices.count == 1, let slice = report.slices.first else {
            throw MachOError.invalidArchitecture
        }
        return slice
    }

    private static func inspectFat(
        path: String,
        data: Data,
        order: ByteOrder,
        is64Bit: Bool
    ) throws -> MachOReport {
        guard let count = readUInt32(data, at: 4, order: order), count > 0,
              count <= UInt32(maximumFatSlices) else {
            throw MachOError.malformedUniversalBinary
        }
        let entrySize = is64Bit ? 32 : 20
        guard let tableBytes = checkedMultiply(Int(count), entrySize),
              let tableEnd = checkedAdd(8, tableBytes),
              tableEnd <= data.count else {
            throw MachOError.truncated
        }

        var entries: [(cpuType: Int32, cpuSubtype: Int32, offset: UInt64, size: UInt64, alignment: UInt32)] = []
        for index in 0..<Int(count) {
            guard let entryOffset = checkedAdd(8, index * entrySize),
                  let cpuType = readInt32(data, at: entryOffset, order: order),
                  let cpuSubtype = readInt32(data, at: entryOffset + 4, order: order),
                  let alignment = (is64Bit
                    ? readUInt32(data, at: entryOffset + 24, order: order)
                    : readUInt32(data, at: entryOffset + 16, order: order)) else {
                throw MachOError.truncated
            }
            let offset: UInt64
            let size: UInt64
            if is64Bit {
                guard let parsedOffset = readUInt64(data, at: entryOffset + 8, order: order),
                      let parsedSize = readUInt64(data, at: entryOffset + 16, order: order) else {
                    throw MachOError.truncated
                }
                offset = parsedOffset
                size = parsedSize
            } else {
                guard let parsedOffset = readUInt32(data, at: entryOffset + 8, order: order),
                      let parsedSize = readUInt32(data, at: entryOffset + 12, order: order) else {
                    throw MachOError.truncated
                }
                offset = UInt64(parsedOffset)
                size = UInt64(parsedSize)
            }
            guard size > 0,
                  alignment <= 63,
                  offset >= UInt64(tableEnd),
                  offset <= UInt64(data.count),
                  size <= UInt64(data.count) - offset,
                  Int(exactly: offset) != nil,
                  Int(exactly: size) != nil else {
                throw MachOError.malformedUniversalBinary
            }
            entries.append((cpuType, cpuSubtype, offset, size, alignment))
        }

        let ranges = entries.map { entry in
            (start: entry.offset, end: entry.offset + entry.size)
        }.sorted { $0.start < $1.start }
        var previousEnd = UInt64(tableEnd)
        for range in ranges {
            guard range.start >= previousEnd else {
                throw MachOError.overlappingSlices
            }
            previousEnd = range.end
        }

        var sliceReports: [MachOSliceReport] = []
        var architectures: [MachOArchitecture] = []
        for entry in entries {
            guard let sliceOffset = Int(exactly: entry.offset),
                  let sliceSize = Int(exactly: entry.size),
                  let sliceEnd = checkedAdd(sliceOffset, sliceSize),
                  sliceEnd <= data.count else {
                throw MachOError.malformedUniversalBinary
            }
            let sliceData = Data(data[sliceOffset..<sliceEnd])
            guard let sliceMagic = readUInt32(sliceData, at: 0, order: .little) else {
                throw MachOError.truncated
            }
            let header: Header
            switch sliceMagic {
            case machMagic32:
                header = Header(order: .little, is64Bit: false, offset: 0, limit: sliceData.count)
            case machMagic64:
                header = Header(order: .little, is64Bit: true, offset: 0, limit: sliceData.count)
            case machCigam32:
                header = Header(order: .big, is64Bit: false, offset: 0, limit: sliceData.count)
            case machCigam64:
                header = Header(order: .big, is64Bit: true, offset: 0, limit: sliceData.count)
            default:
                throw MachOError.unsupportedFormat
            }
            let report = try inspectThinReport(
                path: path,
                data: sliceData,
                header: header,
                fileOffset: entry.offset,
                sliceSize: entry.size,
                alignment: entry.alignment
            )
            guard let sliceArchitecture = report.architectures.first,
                  sliceArchitecture.cpuType == entry.cpuType,
                  sliceArchitecture.cpuSubtype == entry.cpuSubtype else {
                throw MachOError.malformedUniversalBinary
            }
            let architecture = MachOArchitecture(
                cpuType: entry.cpuType,
                cpuSubtype: entry.cpuSubtype,
                fileOffset: entry.offset,
                size: entry.size,
                alignment: entry.alignment,
                name: sliceArchitecture.name,
                uuid: sliceArchitecture.uuid,
                is64Bit: sliceArchitecture.is64Bit,
                byteOrder: sliceArchitecture.byteOrder
            )
            let adjusted = MachOSliceReport(
                path: path,
                format: report.format,
                architecture: architecture,
                fileType: report.fileType ?? 0,
                loadCommandCount: report.loadCommandCount ?? 0,
                sizeofCommands: report.slices.first?.sizeofCommands ?? 0,
                flags: report.flags ?? 0,
                segments: report.segments,
                symbols: report.symbols,
                strings: report.strings
            )
            architectures.append(architecture)
            sliceReports.append(adjusted)
        }

        return MachOReport(
            path: path,
            format: is64Bit ? "Universal Mach-O 64" : "Universal Mach-O",
            architectures: architectures,
            fileType: nil,
            loadCommandCount: nil,
            flags: nil,
            segments: [],
            symbols: [],
            strings: extractStrings(data),
            uuids: architectures.compactMap(\.uuid),
            slices: sliceReports
        )
    }

    private static func inspectThinReport(
        path: String,
        data: Data,
        header: Header,
        fileOffset: UInt64,
        sliceSize: UInt64,
        alignment: UInt32
    ) throws -> MachOReport {
        let slice = try inspectThin(
            path: path,
            data: data,
            header: header,
            fileOffset: fileOffset,
            sliceSize: sliceSize,
            alignment: alignment
        )
        return MachOReport(
            path: path,
            format: slice.format,
            architectures: [slice.architecture],
            fileType: slice.fileType,
            loadCommandCount: slice.loadCommandCount,
            flags: slice.flags,
            segments: slice.segments,
            symbols: slice.symbols,
            strings: slice.strings,
            uuids: slice.uuid.map { [$0] } ?? [],
            slices: [slice]
        )
    }

    private static func inspectThin(
        path: String,
        data: Data,
        header: Header,
        fileOffset: UInt64,
        sliceSize: UInt64,
        alignment: UInt32
    ) throws -> MachOSliceReport {
        let base = header.offset
        let headerSize = header.is64Bit ? 32 : 28
        guard base >= 0,
              let headerEnd = checkedAdd(base, headerSize),
              headerEnd <= header.limit,
              let cpuType = readInt32(data, at: base + 4, order: header.order),
              let cpuSubtype = readInt32(data, at: base + 8, order: header.order),
              let fileType = readUInt32(data, at: base + 12, order: header.order),
              let commandCount = readUInt32(data, at: base + 16, order: header.order),
              let sizeofCommands = readUInt32(data, at: base + 20, order: header.order),
              let flags = readUInt32(data, at: base + 24, order: header.order) else {
            throw MachOError.truncated
        }
        guard commandCount <= UInt32(maximumLoadCommands),
              sizeofCommands <= UInt32(header.limit - headerEnd),
              let commandEnd = checkedAdd(headerEnd, Int(sizeofCommands)),
              commandEnd <= header.limit else {
            throw MachOError.malformedLoadCommand
        }

        var segments: [MachOSegment] = []
        var symbolTable: SymbolTable?
        var uuid: String?
        var commandOffset = headerEnd
        for _ in 0..<Int(commandCount) {
            guard let commandEndMinimum = checkedAdd(commandOffset, 8),
                  commandEndMinimum <= commandEnd,
                  let command = readUInt32(data, at: commandOffset, order: header.order),
                  let commandSize = readUInt32(data, at: commandOffset + 4, order: header.order),
                  commandSize >= 8,
                  commandSize <= UInt32(commandEnd - commandOffset),
                  let nextOffset = checkedAdd(commandOffset, Int(commandSize)),
                  nextOffset <= commandEnd else {
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
                    commandSize: Int(commandSize),
                    limit: header.limit,
                    order: header.order,
                    is64Bit: header.is64Bit
                )
                segments.append(segment)
            }
            if command == symtabCommand {
                guard symbolTable == nil,
                      let symbolOffsetValue = readUInt32(data, at: commandOffset + 8, order: header.order),
                      let symbolCountValue = readUInt32(data, at: commandOffset + 12, order: header.order),
                      let stringOffsetValue = readUInt32(data, at: commandOffset + 16, order: header.order),
                      let stringSizeValue = readUInt32(data, at: commandOffset + 20, order: header.order),
                      let symbolOffset = Int(exactly: symbolOffsetValue),
                      let symbolCount = Int(exactly: symbolCountValue),
                      let stringOffset = Int(exactly: stringOffsetValue),
                      let stringSize = Int(exactly: stringSizeValue) else {
                    throw MachOError.malformedLoadCommand
                }
                symbolTable = SymbolTable(
                    symbolOffset: symbolOffset,
                    symbolCount: symbolCount,
                    stringOffset: stringOffset,
                    stringSize: stringSize
                )
            }
            if command == uuidCommand {
                guard commandSize == 24 else {
                    throw MachOError.invalidUUID
                }
                guard uuid == nil else {
                    throw MachOError.duplicateUUID
                }
                let bytes = data[(commandOffset + 8)..<(commandOffset + 24)]
                let value = bytes.map { String(format: "%02x", $0) }.joined()
                guard let normalized = MachOUUID.normalize(value) else {
                    throw MachOError.invalidUUID
                }
                uuid = normalized
            }
            commandOffset = nextOffset
        }
        guard commandOffset == commandEnd else {
            throw MachOError.malformedLoadCommand
        }
        guard let uuid else {
            throw MachOError.missingUUID
        }

        let architecture = MachOArchitecture(
            cpuType: cpuType,
            cpuSubtype: cpuSubtype,
            fileOffset: fileOffset,
            size: sliceSize,
            alignment: alignment,
            name: architectureName(cpuType: cpuType, cpuSubtype: cpuSubtype),
            uuid: uuid,
            is64Bit: header.is64Bit,
            byteOrder: header.order.name
        )
        return MachOSliceReport(
            path: path,
            format: header.is64Bit ? "Mach-O 64" : "Mach-O 32",
            architecture: architecture,
            fileType: fileType,
            loadCommandCount: commandCount,
            sizeofCommands: sizeofCommands,
            flags: flags,
            segments: segments,
            symbols: try parseSymbols(
                data: data,
                table: symbolTable,
                order: header.order,
                is64Bit: header.is64Bit,
                limit: header.limit
            ),
            strings: extractStrings(data)
        )
    }

    private static func parseSymbols(
        data: Data,
        table: SymbolTable?,
        order: ByteOrder,
        is64Bit: Bool,
        limit: Int
    ) throws -> [MachOSymbol] {
        guard let table, table.symbolCount > 0 else {
            return []
        }
        guard table.symbolCount <= maximumSymbols,
              table.symbolOffset >= 0,
              table.stringOffset >= 0,
              table.stringSize >= 0 else {
            throw MachOError.malformedLoadCommand
        }
        let entrySize = is64Bit ? 16 : 12
        guard let symbolBytes = checkedMultiply(table.symbolCount, entrySize),
              let symbolEnd = checkedAdd(table.symbolOffset, symbolBytes),
              let stringEnd = checkedAdd(table.stringOffset, table.stringSize),
              symbolEnd <= limit,
              stringEnd <= limit else {
            throw MachOError.truncated
        }

        var symbols: [MachOSymbol] = []
        symbols.reserveCapacity(min(table.symbolCount, 20_000))
        for index in 0..<table.symbolCount {
            guard let offset = checkedAdd(table.symbolOffset, index * entrySize),
                  let stringIndex = readUInt32(data, at: offset, order: order) else {
                throw MachOError.truncated
            }
            let type = data[offset + 4]
            let section = data[offset + 5]
            let value: UInt64
            if is64Bit {
                guard let symbolValue = readUInt64(data, at: offset + 8, order: order) else {
                    throw MachOError.truncated
                }
                value = symbolValue
            } else {
                guard let symbolValue = readUInt32(data, at: offset + 8, order: order) else {
                    throw MachOError.truncated
                }
                value = UInt64(symbolValue)
            }
            guard let stringIndex = Int(exactly: stringIndex), stringIndex < table.stringSize else {
                continue
            }
            let nameOffset = table.stringOffset + stringIndex
            let name = readString(data, at: nameOffset, length: table.stringSize - stringIndex)
            if !name.isEmpty {
                symbols.append(MachOSymbol(name: name, type: type, section: section, value: value))
            }
            if symbols.count >= 20_000 {
                break
            }
        }
        return symbols
    }

    private static func parseSegment(
        data: Data,
        offset: Int,
        commandSize: Int,
        limit: Int,
        order: ByteOrder,
        is64Bit: Bool
    ) throws -> MachOSegment {
        let name = readString(data, at: offset + 8, length: 16)
        let sectionSize = is64Bit ? 80 : 68
        let fixedSize = is64Bit ? 72 : 56
        let sectionCountOffset = is64Bit ? offset + 64 : offset + 48
        guard let sectionCount = readUInt32(data, at: sectionCountOffset, order: order),
              let sectionBytes = checkedMultiply(Int(sectionCount), sectionSize),
              let requiredSize = checkedAdd(fixedSize, sectionBytes),
              requiredSize <= commandSize,
              let commandEnd = checkedAdd(offset, commandSize),
              commandEnd <= limit else {
            throw MachOError.malformedLoadCommand
        }
        if is64Bit {
            guard let virtualAddress = readUInt64(data, at: offset + 24, order: order),
                  let virtualSize = readUInt64(data, at: offset + 32, order: order),
                  let fileOffset = readUInt64(data, at: offset + 40, order: order),
                  let fileSize = readUInt64(data, at: offset + 48, order: order),
                  let maxProtection = readInt32(data, at: offset + 56, order: order),
                  let initialProtection = readInt32(data, at: offset + 60, order: order) else {
                throw MachOError.truncated
            }
            guard fileOffset <= UInt64(limit), fileSize <= UInt64(limit) - fileOffset else {
                throw MachOError.malformedLoadCommand
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
              let initialProtection = readInt32(data, at: offset + 44, order: order) else {
            throw MachOError.truncated
        }
        guard UInt64(fileOffset) <= UInt64(limit),
              UInt64(fileSize) <= UInt64(limit) - UInt64(fileOffset) else {
            throw MachOError.malformedLoadCommand
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

    private static func extractStrings(
        _ data: Data,
        minimumLength: Int = 4,
        limit: Int = 2_000
    ) -> [String] {
        var result: [String] = []
        var current: [UInt8] = []
        for byte in data {
            if byte >= 0x20 && byte <= 0x7e {
                current.append(byte)
            } else {
                if current.count >= minimumLength {
                    result.append(String(decoding: current, as: UTF8.self))
                    if result.count == limit {
                        return result
                    }
                }
                current.removeAll(keepingCapacity: true)
            }
        }
        if current.count >= minimumLength && result.count < limit {
            result.append(String(decoding: current, as: UTF8.self))
        }
        return result
    }

    private static func architectureName(cpuType: Int32, cpuSubtype: Int32) -> String {
        let type = UInt32(bitPattern: cpuType)
        let subtype = UInt32(bitPattern: cpuSubtype) & 0x00ff_ffff
        switch type {
        case 0x0100_0007:
            return subtype == 8 ? "x86_64h" : "x86_64"
        case 0x0100_000c:
            return subtype == 2 ? "arm64e" : "arm64"
        case 0x0200_000c:
            return "arm64_32"
        case 0x0000_0007:
            return "x86"
        case 0x0000_000c:
            return "arm"
        default:
            return "cpu-\(cpuType)-subtype-\(cpuSubtype)"
        }
    }

    private static func readString(_ data: Data, at offset: Int, length: Int) -> String {
        guard offset >= 0, length >= 0,
              let end = checkedAdd(offset, length), end <= data.count else {
            return ""
        }
        let bytes = data[offset..<end]
        let stringEnd = bytes.firstIndex(of: 0) ?? bytes.endIndex
        return String(decoding: bytes[..<stringEnd], as: UTF8.self)
    }

    private static func readUInt32(_ data: Data, at offset: Int, order: ByteOrder) -> UInt32? {
        guard offset >= 0, let end = checkedAdd(offset, 4), end <= data.count else { return nil }
        let bytes = data[offset..<end]
        return bytes.enumerated().reduce(UInt32(0)) { partial, item in
            let shift = order == .little ? item.offset * 8 : (3 - item.offset) * 8
            return partial | (UInt32(item.element) << UInt32(shift))
        }
    }

    private static func readInt32(_ data: Data, at offset: Int, order: ByteOrder) -> Int32? {
        guard let value = readUInt32(data, at: offset, order: order) else { return nil }
        return Int32(bitPattern: value)
    }

    private static func readUInt64(_ data: Data, at offset: Int, order: ByteOrder) -> UInt64? {
        guard offset >= 0, let end = checkedAdd(offset, 8), end <= data.count else { return nil }
        let bytes = data[offset..<end]
        return bytes.enumerated().reduce(UInt64(0)) { partial, item in
            let shift = order == .little ? item.offset * 8 : (7 - item.offset) * 8
            return partial | (UInt64(item.element) << UInt64(shift))
        }
    }

    private static func checkedAdd(_ lhs: Int, _ rhs: Int) -> Int? {
        guard rhs >= 0, lhs <= Int.max - rhs else { return nil }
        return lhs + rhs
    }

    private static func checkedMultiply(_ lhs: Int, _ rhs: Int) -> Int? {
        guard lhs >= 0, rhs >= 0, lhs == 0 || rhs <= Int.max / lhs else { return nil }
        return lhs * rhs
    }
}
