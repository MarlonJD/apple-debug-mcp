// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum DyldSharedCacheError: Error, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case inputNotFound
    case notSharedCache
    case malformedHeader
    case outputTooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "dyld shared-cache request is invalid or exceeds its bounded limits."
        case .inputNotFound:
            return "The dyld shared-cache input was not found."
        case .notSharedCache:
            return "The input does not have a dyld shared-cache header."
        case .malformedHeader:
            return "The dyld shared-cache header or table ranges are malformed."
        case .outputTooLarge:
            return "The requested dyld shared-cache report exceeds its bounded limits."
        }
    }
}

public struct DyldSharedCacheMapping: Codable, Equatable, Sendable {
    public let address: String
    public let size: UInt64
    public let fileOffset: UInt64
    public let maximumProtection: UInt32
    public let initialProtection: UInt32

    public init(address: String, size: UInt64, fileOffset: UInt64, maximumProtection: UInt32, initialProtection: UInt32) {
        self.address = address
        self.size = size
        self.fileOffset = fileOffset
        self.maximumProtection = maximumProtection
        self.initialProtection = initialProtection
    }
}

public struct DyldSharedCacheImage: Codable, Equatable, Sendable {
    public let address: String
    public let path: String
    public let modificationTime: UInt64
    public let inode: UInt64

    public init(address: String, path: String, modificationTime: UInt64, inode: UInt64) {
        self.address = address
        self.path = path
        self.modificationTime = modificationTime
        self.inode = inode
    }
}

public struct DyldSharedCacheReport: Codable, Equatable, Sendable {
    public let path: String
    public let magic: String
    public let architecture: String
    public let uuid: String?
    public let dyldBaseAddress: String
    public let codeSignatureOffset: UInt64
    public let codeSignatureSize: UInt64
    public let localSymbolsOffset: UInt64
    public let localSymbolsSize: UInt64
    public let mappings: [DyldSharedCacheMapping]
    public let images: [DyldSharedCacheImage]
    public let imageCount: UInt32
    public let mappingCount: UInt32

    public init(
        path: String,
        magic: String,
        architecture: String,
        uuid: String?,
        dyldBaseAddress: String,
        codeSignatureOffset: UInt64,
        codeSignatureSize: UInt64,
        localSymbolsOffset: UInt64,
        localSymbolsSize: UInt64,
        mappings: [DyldSharedCacheMapping],
        images: [DyldSharedCacheImage],
        imageCount: UInt32,
        mappingCount: UInt32
    ) {
        self.path = path
        self.magic = magic
        self.architecture = architecture
        self.uuid = uuid
        self.dyldBaseAddress = dyldBaseAddress
        self.codeSignatureOffset = codeSignatureOffset
        self.codeSignatureSize = codeSignatureSize
        self.localSymbolsOffset = localSymbolsOffset
        self.localSymbolsSize = localSymbolsSize
        self.mappings = mappings
        self.images = images
        self.imageCount = imageCount
        self.mappingCount = mappingCount
    }
}

public struct DyldSharedCacheDiscovery: Codable, Equatable, Sendable {
    public let searchedRoots: [String]
    public let candidates: [String]
    public let utilityAvailable: Bool

    public init(searchedRoots: [String], candidates: [String], utilityAvailable: Bool) {
        self.searchedRoots = searchedRoots
        self.candidates = candidates
        self.utilityAvailable = utilityAvailable
    }
}

public enum AppleDyldSharedCacheService {
    private static let headerSize = 256
    private static let maximumMappings = 100_000
    private static let maximumImages = 100_000
    private static let maximumPathLength = 1_024

    public static func discover() -> DyldSharedCacheDiscovery {
        let roots = [
            "/System/Library/dyld",
            "/Library/Developer/CoreSimulator/Profiles/Runtimes",
            "/Library/Developer/CoreSimulator/Volumes",
            "/Applications/Xcode.app/Contents/Developer/Platforms"
        ]
        var candidates = Set<String>()
        for root in roots where FileManager.default.fileExists(atPath: root) {
            guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { continue }
            var count = 0
            for case let url as URL in enumerator {
                count += 1
                if count > 50_000 { break }
                if url.lastPathComponent.hasPrefix("dyld_shared_cache") { candidates.insert(url.path) }
            }
        }
        return DyldSharedCacheDiscovery(
            searchedRoots: roots,
            candidates: candidates.sorted(),
            utilityAvailable: ToolchainProbe.path(for: "dyld_shared_cache_util") != nil
        )
    }

    public static func inspect(
        path: String,
        imageFilter: String? = nil,
        maximumImages: Int = 10_000
    ) throws -> DyldSharedCacheReport {
        guard !path.isEmpty, path.utf8.count <= 4_096, !path.contains("\0"),
              URL(fileURLWithPath: path).path.hasPrefix("/"),
              (1...10_000).contains(maximumImages),
              imageFilter.map({ !$0.isEmpty && $0.utf8.count <= 512 && !$0.contains("\0") }) ?? true else {
            throw DyldSharedCacheError.invalidRequest
        }
        guard FileManager.default.fileExists(atPath: path) else {
            throw DyldSharedCacheError.inputNotFound
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard let fileSize = attributes[.size] as? NSNumber, fileSize.uint64Value >= UInt64(headerSize) else {
            throw DyldSharedCacheError.malformedHeader
        }
        let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        defer { try? handle.close() }
        let header = try read(handle: handle, offset: 0, length: headerSize)
        let magicBytes = header.prefix(16)
        guard let rawMagic = String(data: magicBytes, encoding: .ascii) else {
            throw DyldSharedCacheError.notSharedCache
        }
        let magic = rawMagic.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        guard magic.hasPrefix("dyld_v") else { throw DyldSharedCacheError.notSharedCache }
        let mappingOffset = try uint32(header, offset: 16)
        let mappingCount = try uint32(header, offset: 20)
        let imagesOffset = try uint32(header, offset: 24)
        let imageCount = try uint32(header, offset: 28)
        guard mappingCount <= maximumMappings, imageCount <= maximumImages,
              rangeIsValid(offset: UInt64(mappingOffset), length: UInt64(mappingCount) * 32, fileSize: fileSize.uint64Value),
              rangeIsValid(offset: UInt64(imagesOffset), length: UInt64(imageCount) * 32, fileSize: fileSize.uint64Value) else {
            throw DyldSharedCacheError.malformedHeader
        }

        let baseAddress = try uint64(header, offset: 32)
        let codeSignatureOffset = try uint64(header, offset: 40)
        let codeSignatureSize = try uint64(header, offset: 48)
        let localSymbolsOffset = try uint64(header, offset: 72)
        let localSymbolsSize = try uint64(header, offset: 80)
        let uuid = parseUUID(header, offset: 88)
        let mappings = try parseMappings(handle: handle, offset: UInt64(mappingOffset), count: mappingCount, fileSize: fileSize.uint64Value)
        let images = try parseImages(
            handle: handle,
            offset: UInt64(imagesOffset),
            count: imageCount,
            fileSize: fileSize.uint64Value,
            imageFilter: imageFilter,
            maximumImages: maximumImages
        )
        let architecture = magic.split(separator: " ").last.map(String.init) ?? "unknown"
        return DyldSharedCacheReport(
            path: path,
            magic: magic,
            architecture: architecture,
            uuid: uuid,
            dyldBaseAddress: format(baseAddress),
            codeSignatureOffset: codeSignatureOffset,
            codeSignatureSize: codeSignatureSize,
            localSymbolsOffset: localSymbolsOffset,
            localSymbolsSize: localSymbolsSize,
            mappings: mappings,
            images: images,
            imageCount: imageCount,
            mappingCount: mappingCount
        )
    }

    private static func parseMappings(handle: FileHandle, offset: UInt64, count: UInt32, fileSize: UInt64) throws -> [DyldSharedCacheMapping] {
        var values: [DyldSharedCacheMapping] = []
        for index in 0..<UInt64(count) {
            let bytes = try read(handle: handle, offset: offset + index * 32, length: 32)
            values.append(
                DyldSharedCacheMapping(
                    address: format(try uint64(bytes, offset: 0)),
                    size: try uint64(bytes, offset: 8),
                    fileOffset: try uint64(bytes, offset: 16),
                    maximumProtection: try uint32(bytes, offset: 24),
                    initialProtection: try uint32(bytes, offset: 28)
                )
            )
        }
        _ = fileSize
        return values
    }

    private static func parseImages(
        handle: FileHandle,
        offset: UInt64,
        count: UInt32,
        fileSize: UInt64,
        imageFilter: String?,
        maximumImages: Int
    ) throws -> [DyldSharedCacheImage] {
        var values: [DyldSharedCacheImage] = []
        for index in 0..<UInt64(count) {
            let bytes = try read(handle: handle, offset: offset + index * 32, length: 32)
            let pathOffset = UInt64(try uint32(bytes, offset: 24))
            guard pathOffset < fileSize else { throw DyldSharedCacheError.malformedHeader }
            let imagePath = try readCString(handle: handle, offset: pathOffset, fileSize: fileSize)
            guard imageFilter.map({ imagePath.localizedCaseInsensitiveContains($0) }) ?? true else { continue }
            values.append(
                DyldSharedCacheImage(
                    address: format(try uint64(bytes, offset: 0)),
                    path: imagePath,
                    modificationTime: try uint64(bytes, offset: 8),
                    inode: try uint64(bytes, offset: 16)
                )
            )
            if values.count >= maximumImages { break }
        }
        return values
    }

    private static func readCString(handle: FileHandle, offset: UInt64, fileSize: UInt64) throws -> String {
        let length = min(UInt64(maximumPathLength), fileSize - offset)
        let data = try read(handle: handle, offset: offset, length: Int(length))
        let prefix = data.prefix { $0 != 0 }
        guard let value = String(data: prefix, encoding: .utf8), !value.isEmpty else {
            throw DyldSharedCacheError.malformedHeader
        }
        return value
    }

    private static func read(handle: FileHandle, offset: UInt64, length: Int) throws -> Data {
        try handle.seek(toOffset: offset)
        let data = try handle.read(upToCount: length) ?? Data()
        guard data.count == length else { throw DyldSharedCacheError.malformedHeader }
        return data
    }

    private static func uint32(_ data: Data, offset: Int) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else { throw DyldSharedCacheError.malformedHeader }
        return data[offset..<(offset + 4)].enumerated().reduce(UInt32(0)) { result, item in
            result | UInt32(item.element) << UInt32(item.offset * 8)
        }
    }

    private static func uint64(_ data: Data, offset: Int) throws -> UInt64 {
        guard offset >= 0, offset + 8 <= data.count else { throw DyldSharedCacheError.malformedHeader }
        return data[offset..<(offset + 8)].enumerated().reduce(UInt64(0)) { result, item in
            result | UInt64(item.element) << UInt64(item.offset * 8)
        }
    }

    private static func rangeIsValid(offset: UInt64, length: UInt64, fileSize: UInt64) -> Bool {
        offset <= fileSize && length <= fileSize - offset
    }

    private static func parseUUID(_ data: Data, offset: Int) -> String? {
        guard offset >= 0, offset + 16 <= data.count else { return nil }
        let bytes = data[offset..<(offset + 16)]
        guard bytes.contains(where: { $0 != 0 }) else { return nil }
        let values = bytes.map { String(format: "%02X", $0) }
        return ([values[0..<4].joined(), values[4..<6].joined(), values[6..<8].joined(), values[8..<10].joined(), values[10..<16].joined()]).joined(separator: "-")
    }

    private static func format(_ value: UInt64) -> String {
        "0x\(String(value, radix: 16))"
    }
}
