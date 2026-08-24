// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum DyldSharedCacheError: Error, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case inputNotFound
    case notSharedCache
    case malformedHeader
    case imageNotFound
    case malformedImage
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
        case .imageNotFound:
            return "The requested image was not found in the dyld shared-cache image table."
        case .malformedImage:
            return "The selected shared-cache image does not contain a bounded, readable Mach-O image."
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

public struct DyldSharedCacheImageSegment: Codable, Equatable, Sendable {
    public let name: String
    public let virtualAddress: String
    public let virtualSize: UInt64
    public let fileOffset: UInt64
    public let fileSize: UInt64
    public let maximumProtection: Int32
    public let initialProtection: Int32

    public init(name: String, virtualAddress: String, virtualSize: UInt64, fileOffset: UInt64, fileSize: UInt64, maximumProtection: Int32, initialProtection: Int32) {
        self.name = name
        self.virtualAddress = virtualAddress
        self.virtualSize = virtualSize
        self.fileOffset = fileOffset
        self.fileSize = fileSize
        self.maximumProtection = maximumProtection
        self.initialProtection = initialProtection
    }
}

public struct DyldSharedCacheExport: Codable, Equatable, Sendable {
    public let name: String
    public let address: String?
    public let flags: UInt64
    public let reexportName: String?

    public init(name: String, address: String?, flags: UInt64, reexportName: String?) {
        self.name = name
        self.address = address
        self.flags = flags
        self.reexportName = reexportName
    }
}

public struct DyldSharedCacheSymbol: Codable, Equatable, Sendable {
    public let name: String
    public let address: String
    public let type: UInt8
    public let section: UInt8
    public let description: UInt16

    public init(name: String, address: String, type: UInt8, section: UInt8, description: UInt16) {
        self.name = name
        self.address = address
        self.type = type
        self.section = section
        self.description = description
    }
}

public struct DyldSharedCacheChainedFixup: Codable, Equatable, Sendable {
    public let segmentIndex: Int
    public let segmentOffset: UInt64
    public let pageSize: UInt16
    public let pointerFormat: UInt16
    public let pageStarts: [UInt16]

    public init(segmentIndex: Int, segmentOffset: UInt64, pageSize: UInt16, pointerFormat: UInt16, pageStarts: [UInt16]) {
        self.segmentIndex = segmentIndex
        self.segmentOffset = segmentOffset
        self.pageSize = pageSize
        self.pointerFormat = pointerFormat
        self.pageStarts = pageStarts
    }
}

public struct DyldSharedCacheFixupImport: Codable, Equatable, Sendable {
    public let name: String
    public let libraryOrdinal: Int32
    public let weakImport: Bool
    public let addend: Int64

    public init(name: String, libraryOrdinal: Int32, weakImport: Bool, addend: Int64) {
        self.name = name
        self.libraryOrdinal = libraryOrdinal
        self.weakImport = weakImport
        self.addend = addend
    }
}

public struct DyldSharedCacheRuntimeReference: Codable, Equatable, Sendable {
    public let kind: String
    public let section: String
    public let offset: UInt64
    public let value: String

    public init(kind: String, section: String, offset: UInt64, value: String) {
        self.kind = kind
        self.section = section
        self.offset = offset
        self.value = value
    }
}

public struct DyldSharedCacheCrossReference: Codable, Equatable, Sendable {
    public let sourceSection: String
    public let sourceAddress: UInt64
    public let targetKind: String
    public let targetSection: String
    public let targetAddress: UInt64
    public let targetValue: String

    public init(sourceSection: String, sourceAddress: UInt64, targetKind: String, targetSection: String, targetAddress: UInt64, targetValue: String) {
        self.sourceSection = sourceSection
        self.sourceAddress = sourceAddress
        self.targetKind = targetKind
        self.targetSection = targetSection
        self.targetAddress = targetAddress
        self.targetValue = targetValue
    }
}

public struct DyldSharedCacheImageAnalysis: Codable, Equatable, Sendable {
    public let cachePath: String
    public let image: DyldSharedCacheImage
    public let fileOffset: UInt64
    public let magic: String
    public let cpuType: Int32
    public let cpuSubtype: Int32
    public let uuid: String?
    public let segments: [DyldSharedCacheImageSegment]
    public let exports: [DyldSharedCacheExport]
    public let symbols: [DyldSharedCacheSymbol]
    public let chainedFixups: [DyldSharedCacheChainedFixup]
    public let fixupImports: [DyldSharedCacheFixupImport]
    public let runtimeReferences: [DyldSharedCacheRuntimeReference]
    public let crossReferences: [DyldSharedCacheCrossReference]
    public let notes: [String]

    public init(cachePath: String, image: DyldSharedCacheImage, fileOffset: UInt64, magic: String, cpuType: Int32, cpuSubtype: Int32, uuid: String?, segments: [DyldSharedCacheImageSegment], exports: [DyldSharedCacheExport], symbols: [DyldSharedCacheSymbol], chainedFixups: [DyldSharedCacheChainedFixup], fixupImports: [DyldSharedCacheFixupImport], runtimeReferences: [DyldSharedCacheRuntimeReference], crossReferences: [DyldSharedCacheCrossReference], notes: [String]) {
        self.cachePath = cachePath
        self.image = image
        self.fileOffset = fileOffset
        self.magic = magic
        self.cpuType = cpuType
        self.cpuSubtype = cpuSubtype
        self.uuid = uuid
        self.segments = segments
        self.exports = exports
        self.symbols = symbols
        self.chainedFixups = chainedFixups
        self.fixupImports = fixupImports
        self.runtimeReferences = runtimeReferences
        self.crossReferences = crossReferences
        self.notes = notes
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
    public let runtimeHelpers: [String]
    public let utilityAvailable: Bool
    public let notes: [String]

    public init(searchedRoots: [String], candidates: [String], runtimeHelpers: [String], utilityAvailable: Bool, notes: [String]) {
        self.searchedRoots = searchedRoots
        self.candidates = candidates
        self.runtimeHelpers = runtimeHelpers
        self.utilityAvailable = utilityAvailable
        self.notes = notes
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
            "/Applications/Xcode.app/Contents/Developer/Platforms",
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Developer/CoreSimulator").path
        ]
        var candidates = Set<String>()
        var runtimeHelpers = Set<String>()
        for root in roots where FileManager.default.fileExists(atPath: root) {
            collectKnownRuntimeArtifacts(
                root: URL(fileURLWithPath: root),
                candidates: &candidates,
                runtimeHelpers: &runtimeHelpers
            )
            guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { continue }
            var count = 0
            for case let url as URL in enumerator {
                count += 1
                if count > 50_000 { break }
                let name = url.lastPathComponent.localizedLowercase
                if name.hasPrefix("dyld_shared_cache") || name.hasPrefix("dyld_sim_shared_cache") {
                    candidates.insert(url.path)
                }
                if name == "update_dyld_sim_shared_cache" {
                    runtimeHelpers.insert(url.path)
                }
            }
        }
        let notes: [String]
        if candidates.isEmpty && !runtimeHelpers.isEmpty {
            notes = [
                "No mounted dyld shared-cache file was found in the bounded roots.",
                "A public Simulator runtime cache-update helper was found; private cache utilities and private runtime databases were not assumed."
            ]
        } else if candidates.isEmpty {
            notes = ["No mounted dyld shared-cache file was found in the bounded roots."]
        } else {
            notes = ["Mounted cache candidates were discovered; inspect each with the public header, mapping, UUID, and image-table parser."]
        }
        return DyldSharedCacheDiscovery(
            searchedRoots: roots,
            candidates: candidates.sorted(),
            runtimeHelpers: runtimeHelpers.sorted(),
            utilityAvailable: ToolchainProbe.path(for: "dyld_shared_cache_util") != nil,
            notes: notes
        )
    }

    private static func collectKnownRuntimeArtifacts(
        root: URL,
        candidates: inout Set<String>,
        runtimeHelpers: inout Set<String>
    ) {
        var runtimeRoots = [
            root,
            root.appendingPathComponent("Library/Developer/CoreSimulator/Profiles/Runtimes")
        ]
        if let children = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            runtimeRoots.append(contentsOf: children.map {
                $0.appendingPathComponent("Library/Developer/CoreSimulator/Profiles/Runtimes")
            })
        }

        for runtimeRoot in runtimeRoots {
            guard let runtimes = try? FileManager.default.contentsOfDirectory(
                at: runtimeRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for runtime in runtimes.prefix(256) where runtime.pathExtension == "simruntime" {
                let resources = runtime.appendingPathComponent("Contents/Resources")
                let helper = resources.appendingPathComponent("update_dyld_sim_shared_cache")
                appendRegularFile(helper, runtimeHelpers: &runtimeHelpers)
                if let resourceEntries = try? FileManager.default.contentsOfDirectory(
                    at: resources,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for entry in resourceEntries.prefix(512) {
                        appendCacheOrHelper(entry, candidates: &candidates, runtimeHelpers: &runtimeHelpers)
                    }
                }
                let dyldRoot = resources.appendingPathComponent("RuntimeRoot/System/Library/dyld")
                if let dyldEntries = try? FileManager.default.contentsOfDirectory(
                    at: dyldRoot,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for entry in dyldEntries.prefix(512) {
                        appendCacheOrHelper(entry, candidates: &candidates, runtimeHelpers: &runtimeHelpers)
                    }
                }
            }
        }
    }

    private static func appendCacheOrHelper(
        _ url: URL,
        candidates: inout Set<String>,
        runtimeHelpers: inout Set<String>
    ) {
        let name = url.lastPathComponent.localizedLowercase
        if name.hasPrefix("dyld_shared_cache") || name.hasPrefix("dyld_sim_shared_cache") {
            appendRegularFile(url, candidates: &candidates)
        } else if name == "update_dyld_sim_shared_cache" {
            appendRegularFile(url, runtimeHelpers: &runtimeHelpers)
        }
    }

    private static func appendRegularFile(_ url: URL, candidates: inout Set<String>) {
        guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return }
        candidates.insert(url.path)
    }

    private static func appendRegularFile(_ url: URL, runtimeHelpers: inout Set<String>) {
        guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return }
        runtimeHelpers.insert(url.path)
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

    public static func analyzeImage(
        path: String,
        imagePath: String,
        maximumExports: Int = 5_000,
        maximumSymbols: Int = 5_000
    ) throws -> DyldSharedCacheImageAnalysis {
        guard !imagePath.isEmpty, imagePath.utf8.count <= maximumPathLength, !imagePath.contains("\0"),
              (1...20_000).contains(maximumExports), (1...20_000).contains(maximumSymbols) else {
            throw DyldSharedCacheError.invalidRequest
        }
        let report = try inspect(path: path, imageFilter: imagePath, maximumImages: 10_000)
        guard let image = report.images.first(where: { $0.path == imagePath }) else {
            throw DyldSharedCacheError.imageNotFound
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard let fileSize = attributes[.size] as? NSNumber else { throw DyldSharedCacheError.malformedHeader }
        guard let imageAddress = parseAddress(image.address),
              let imageFileOffset = fileOffset(for: imageAddress, mappings: report.mappings) else {
            throw DyldSharedCacheError.malformedImage
        }
        let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        defer { try? handle.close() }
        return try parseImage(
            handle: handle,
            cachePath: path,
            image: image,
            imageFileOffset: imageFileOffset,
            imageBaseAddress: imageAddress,
            fileSize: fileSize.uint64Value,
            maximumExports: maximumExports,
            maximumSymbols: maximumSymbols
        )
    }

    private static func parseImage(
        handle: FileHandle,
        cachePath: String,
        image: DyldSharedCacheImage,
        imageFileOffset: UInt64,
        imageBaseAddress: UInt64,
        fileSize: UInt64,
        maximumExports: Int,
        maximumSymbols: Int
    ) throws -> DyldSharedCacheImageAnalysis {
        let header = try read(handle: handle, offset: imageFileOffset, length: 32)
        let magicValue = try uint32(header, offset: 0)
        let is64Bit: Bool
        let magic: String
        switch magicValue {
        case 0xfeedfacf:
            is64Bit = true
            magic = "MH_MAGIC_64"
        case 0xfeedface:
            is64Bit = false
            magic = "MH_MAGIC"
        default:
            throw DyldSharedCacheError.malformedImage
        }
        guard is64Bit else {
            return DyldSharedCacheImageAnalysis(
                cachePath: cachePath,
                image: image,
                fileOffset: imageFileOffset,
                magic: magic,
                cpuType: Int32(bitPattern: try uint32(header, offset: 4)),
                cpuSubtype: Int32(bitPattern: try uint32(header, offset: 8)),
                uuid: nil,
                segments: [],
                exports: [],
                symbols: [],
                chainedFixups: [],
                fixupImports: [],
                runtimeReferences: [],
                crossReferences: [],
                notes: ["32-bit shared-cache Mach-O images are identified but deep export/symbol extraction is only enabled for bounded 64-bit images."]
            )
        }

        let cpuType = Int32(bitPattern: try uint32(header, offset: 4))
        let cpuSubtype = Int32(bitPattern: try uint32(header, offset: 8))
        let commandCount = try uint32(header, offset: 16)
        let commandSize = try uint32(header, offset: 20)
        guard commandCount <= 4_096, commandSize <= 8 * 1024 * 1024,
              rangeIsValid(offset: imageFileOffset + 32, length: UInt64(commandSize), fileSize: fileSize) else {
            throw DyldSharedCacheError.malformedImage
        }
        let commands = try read(handle: handle, offset: imageFileOffset + 32, length: Int(commandSize))
        var segments: [DyldSharedCacheImageSegment] = []
        var uuid: String?
        var exportOffset: UInt64?
        var exportSize: UInt64 = 0
        var symbolOffset: UInt64?
        var symbolCount: UInt32 = 0
        var stringOffset: UInt64?
        var stringSize: UInt64 = 0
        var chainedOffset: UInt64?
        var chainedSize: UInt64 = 0
        var sections: [(name: String, offset: UInt64, size: UInt64, address: UInt64)] = []
        var cursor = 0
        for _ in 0..<commandCount {
            guard cursor + 8 <= commands.count else { throw DyldSharedCacheError.malformedImage }
            let command = try uint32(commands, offset: cursor)
            let size = try uint32(commands, offset: cursor + 4)
            guard size >= 8, Int(size) <= commands.count - cursor else { throw DyldSharedCacheError.malformedImage }
            let commandData = commands.subdata(in: cursor..<(cursor + Int(size)))
            switch command {
            case 0x19 where size >= 72:
                let segmentName = readFixedCString(commandData, offset: 8, length: 16)
                let segmentAddress = try uint64(commandData, offset: 24)
                segments.append(
                    DyldSharedCacheImageSegment(
                        name: segmentName,
                        virtualAddress: format(segmentAddress),
                        virtualSize: try uint64(commandData, offset: 32),
                        fileOffset: try uint64(commandData, offset: 40),
                        fileSize: try uint64(commandData, offset: 48),
                        maximumProtection: Int32(bitPattern: try uint32(commandData, offset: 56)),
                        initialProtection: Int32(bitPattern: try uint32(commandData, offset: 60))
                    )
                )
                let sectionCount = Int(try uint32(commandData, offset: 64))
                for sectionIndex in 0..<min(sectionCount, 1_024) {
                    let sectionOffset = 72 + sectionIndex * 80
                    guard sectionOffset + 80 <= commandData.count else { break }
                    let sectionName = readFixedCString(commandData, offset: sectionOffset, length: 16)
                    let sectionAddress = try uint64(commandData, offset: sectionOffset + 32)
                    let sectionSize = try uint64(commandData, offset: sectionOffset + 40)
                    let rawSectionOffset = UInt64(try uint32(commandData, offset: sectionOffset + 48))
                    sections.append((sectionName, rawSectionOffset, sectionSize, sectionAddress))
                }
            case 0x1b where size >= 24:
                uuid = parseUUID(commandData, offset: 8)
            case 0x2 where size >= 24:
                symbolOffset = UInt64(try uint32(commandData, offset: 8))
                symbolCount = try uint32(commandData, offset: 12)
                stringOffset = UInt64(try uint32(commandData, offset: 16))
                stringSize = UInt64(try uint32(commandData, offset: 20))
            case 0x22 where size >= 48:
                exportOffset = UInt64(try uint32(commandData, offset: 40))
                exportSize = UInt64(try uint32(commandData, offset: 44))
            case 0x80000033 where size >= 24:
                exportOffset = try uint64(commandData, offset: 8)
                exportSize = try uint64(commandData, offset: 16)
            case 0x80000034 where size >= 16:
                chainedOffset = UInt64(try uint32(commandData, offset: 8))
                chainedSize = UInt64(try uint32(commandData, offset: 12))
            default:
                break
            }
            cursor += Int(size)
        }

        var exports: [DyldSharedCacheExport] = []
        if let exportOffset, exportSize > 0,
           let data = try readMachOData(handle: handle, rawOffset: exportOffset, imageFileOffset: imageFileOffset, size: exportSize, fileSize: fileSize) {
            exports = parseExportTrie(data: data, imageBaseAddress: imageBaseAddress, maximumExports: maximumExports)
        }
        var symbols: [DyldSharedCacheSymbol] = []
        if let symbolOffset, let stringOffset, symbolCount > 0, stringSize > 0 {
            symbols = try parseSymbols(
                handle: handle,
                symbolOffset: symbolOffset,
                symbolCount: symbolCount,
                stringOffset: stringOffset,
                stringSize: stringSize,
                imageFileOffset: imageFileOffset,
                fileSize: fileSize,
                maximumSymbols: maximumSymbols
            )
        }
        var chainedFixups: [DyldSharedCacheChainedFixup] = []
        var fixupImports: [DyldSharedCacheFixupImport] = []
        if let chainedOffset, chainedSize > 0,
           let data = try readMachOData(handle: handle, rawOffset: chainedOffset, imageFileOffset: imageFileOffset, size: chainedSize, fileSize: fileSize) {
            let parsed = parseChainedFixups(data: data, maximumImports: maximumSymbols)
            chainedFixups = parsed.chains
            fixupImports = parsed.imports
        }
        let runtimeReferences = try parseRuntimeReferences(
            handle: handle,
            sections: sections,
            imageFileOffset: imageFileOffset,
            fileSize: fileSize
        )
        let crossReferences = try parseCrossReferences(
            handle: handle,
            sections: sections,
            targets: runtimeReferences,
            imageFileOffset: imageFileOffset,
            fileSize: fileSize
        )
        var notes = [
            "Mach-O load commands, exports, chained-fixups metadata, and runtime sections are decoded from public shared-cache bytes; no private dyld database is accessed."
        ]
        if exports.isEmpty { notes.append("The image did not expose a bounded export trie through its public load commands.") }
        if symbols.isEmpty { notes.append("The image did not expose a bounded LC_SYMTAB symbol table; modern shared caches may keep local symbols in separate tables.") }
        if chainedFixups.isEmpty { notes.append("The image did not expose a bounded LC_DYLD_CHAINED_FIXUPS payload.") }
        if runtimeReferences.isEmpty { notes.append("No bounded ObjC/Swift runtime reference sections were present in the selected image.") }
        if crossReferences.isEmpty, !runtimeReferences.isEmpty {
            notes.append("Runtime strings were found, but no direct 64-bit data pointers to them were observed; authenticated or chained pointers are not rewritten by this read-only scan.")
        }
        if symbolCount > UInt32(maximumSymbols) { notes.append("The symbol table was bounded at maximumSymbols=\(maximumSymbols).") }
        return DyldSharedCacheImageAnalysis(
            cachePath: cachePath,
            image: image,
            fileOffset: imageFileOffset,
            magic: magic,
            cpuType: cpuType,
            cpuSubtype: cpuSubtype,
            uuid: uuid,
            segments: segments,
            exports: exports,
            symbols: symbols,
            chainedFixups: chainedFixups,
            fixupImports: fixupImports,
            runtimeReferences: runtimeReferences,
            crossReferences: crossReferences,
            notes: notes
        )
    }

    private static func fileOffset(for address: UInt64, mappings: [DyldSharedCacheMapping]) -> UInt64? {
        for mapping in mappings {
            guard let mappingAddress = parseAddress(mapping.address),
                  address >= mappingAddress,
                  address - mappingAddress < mapping.size else { continue }
            return mapping.fileOffset + (address - mappingAddress)
        }
        return nil
    }

    private static func readMachOData(
        handle: FileHandle,
        rawOffset: UInt64,
        imageFileOffset: UInt64,
        size: UInt64,
        fileSize: UInt64
    ) throws -> Data? {
        guard size > 0, size <= 32 * 1024 * 1024 else { return nil }
        var offsets = [rawOffset]
        let relative = imageFileOffset.addingReportingOverflow(rawOffset)
        if !relative.overflow, relative.partialValue != rawOffset {
            offsets.append(relative.partialValue)
        }
        for offset in offsets where rangeIsValid(offset: offset, length: size, fileSize: fileSize) {
            return try read(handle: handle, offset: offset, length: Int(size))
        }
        return nil
    }

    private static func readFixedCString(_ data: Data, offset: Int, length: Int) -> String {
        guard offset >= 0, length >= 0, offset + length <= data.count else { return "" }
        let bytes = data[offset..<(offset + length)]
        let prefix = bytes.prefix { $0 != 0 }
        return String(data: prefix, encoding: .utf8) ?? ""
    }

    private static func parseSymbols(
        handle: FileHandle,
        symbolOffset: UInt64,
        symbolCount: UInt32,
        stringOffset: UInt64,
        stringSize: UInt64,
        imageFileOffset: UInt64,
        fileSize: UInt64,
        maximumSymbols: Int
    ) throws -> [DyldSharedCacheSymbol] {
        let count = min(Int(symbolCount), maximumSymbols)
        guard let symbolData = try readMachOData(
            handle: handle,
            rawOffset: symbolOffset,
            imageFileOffset: imageFileOffset,
            size: UInt64(count) * 16,
            fileSize: fileSize
        ),
        let stringData = try readMachOData(
            handle: handle,
            rawOffset: stringOffset,
            imageFileOffset: imageFileOffset,
            size: stringSize,
            fileSize: fileSize
        ) else {
            return []
        }
        var values: [DyldSharedCacheSymbol] = []
        for index in 0..<count {
            let offset = index * 16
            guard let stringIndex = try? uint32(symbolData, offset: offset),
                  Int(stringIndex) < stringData.count else { continue }
            let nameBytes = stringData[Int(stringIndex)...]
            let namePrefix = nameBytes.prefix { $0 != 0 }
            guard let name = String(data: namePrefix, encoding: .utf8), !name.isEmpty else { continue }
            guard let type = try? uint32(symbolData, offset: offset + 4),
                  let section = try? uint32(symbolData, offset: offset + 5),
                  let description = try? uint32(symbolData, offset: offset + 6),
                  let address = try? uint64(symbolData, offset: offset + 8) else { continue }
            values.append(
                DyldSharedCacheSymbol(
                    name: name,
                    address: format(address),
                    type: UInt8(type & 0xff),
                    section: UInt8(section & 0xff),
                    description: UInt16(description & 0xffff)
                )
            )
        }
        return values.sorted { $0.name == $1.name ? $0.address < $1.address : $0.name < $1.name }
    }

    private static func parseExportTrie(
        data: Data,
        imageBaseAddress: UInt64,
        maximumExports: Int
    ) -> [DyldSharedCacheExport] {
        var visited = Set<Int>()
        var exports: [DyldSharedCacheExport] = []

        func readULEB(_ offset: inout Int) -> UInt64? {
            var value: UInt64 = 0
            var shift: UInt64 = 0
            for _ in 0..<10 {
                guard offset < data.count else { return nil }
                let byte = data[offset]
                offset += 1
                value |= UInt64(byte & 0x7f) << shift
                if byte & 0x80 == 0 { return value }
                shift += 7
            }
            return nil
        }

        func readCString(_ offset: inout Int) -> String? {
            let start = offset
            while offset < data.count, data[offset] != 0 { offset += 1 }
            guard offset < data.count else { return nil }
            let value = String(data: data[start..<offset], encoding: .utf8)
            offset += 1
            return value
        }

        func visit(_ nodeOffset: Int, name: String, depth: Int) {
            guard exports.count < maximumExports,
                  depth <= 256,
                  nodeOffset >= 0,
                  nodeOffset < data.count,
                  visited.insert(nodeOffset).inserted else { return }
            var cursor = nodeOffset
            guard let terminalSize = readULEB(&cursor),
                  terminalSize <= UInt64(data.count - cursor) else { return }
            let terminalEnd = cursor + Int(terminalSize)
            if terminalSize > 0 {
                var terminalCursor = cursor
                guard let flags = readULEB(&terminalCursor) else { return }
                if flags & 0x8 != 0 {
                    _ = readULEB(&terminalCursor)
                    let reexportName = readCString(&terminalCursor)
                    if !name.isEmpty {
                        exports.append(DyldSharedCacheExport(name: name, address: nil, flags: flags, reexportName: reexportName))
                    }
                } else if let addressOffset = readULEB(&terminalCursor) {
                    if flags & 0x10 != 0 {
                        _ = readULEB(&terminalCursor)
                        _ = readULEB(&terminalCursor)
                    }
                    if !name.isEmpty {
                        let (address, overflow) = imageBaseAddress.addingReportingOverflow(addressOffset)
                        exports.append(
                            DyldSharedCacheExport(
                                name: name,
                                address: overflow ? nil : format(address),
                                flags: flags,
                                reexportName: nil
                            )
                        )
                    }
                }
            }
            cursor = terminalEnd
            guard cursor < data.count else { return }
            let childCount = Int(data[cursor])
            cursor += 1
            for _ in 0..<childCount {
                guard let edge = readCString(&cursor), let child = readULEB(&cursor) else { return }
                visit(Int(child), name: name + edge, depth: depth + 1)
                if exports.count >= maximumExports { return }
            }
        }

        visit(0, name: "", depth: 0)
        return exports.sorted { $0.name == $1.name ? ($0.address ?? "") < ($1.address ?? "") : $0.name < $1.name }
    }

    private static func parseChainedFixups(
        data: Data,
        maximumImports: Int
    ) -> (chains: [DyldSharedCacheChainedFixup], imports: [DyldSharedCacheFixupImport]) {
        guard data.count >= 28,
              let startsOffset = try? uint32(data, offset: 4),
              let importsOffset = try? uint32(data, offset: 8),
              let symbolsOffset = try? uint32(data, offset: 12),
              let importsCount = try? uint32(data, offset: 16),
              let importsFormat = try? uint32(data, offset: 20) else {
            return ([], [])
        }
        var chains: [DyldSharedCacheChainedFixup] = []
        if Int(startsOffset) + 4 <= data.count,
           let segmentCount = try? uint32(data, offset: Int(startsOffset)) {
            for index in 0..<min(Int(segmentCount), 4_096) {
                let offset = Int(startsOffset) + 4 + index * 4
                guard offset + 4 <= data.count,
                      let segmentOffset = try? uint32(data, offset: offset),
                      segmentOffset != 0,
                      Int(startsOffset) + Int(segmentOffset) + 22 <= data.count,
                      let size = try? uint32(data, offset: Int(startsOffset) + Int(segmentOffset)),
                      let pageSize = try? uint16(data, offset: Int(startsOffset) + Int(segmentOffset) + 4),
                      let pointerFormat = try? uint16(data, offset: Int(startsOffset) + Int(segmentOffset) + 6),
                      let segmentVMOffset = try? uint64(data, offset: Int(startsOffset) + Int(segmentOffset) + 8),
                      let pageCount = try? uint16(data, offset: Int(startsOffset) + Int(segmentOffset) + 20),
                      size >= 22,
                      Int(startsOffset) + Int(segmentOffset) + 22 + Int(pageCount) * 2 <= data.count else { continue }
                var pageStarts: [UInt16] = []
                for pageIndex in 0..<Int(pageCount) {
                    if let pageStart = try? uint16(data, offset: Int(startsOffset) + Int(segmentOffset) + 22 + pageIndex * 2) {
                        pageStarts.append(pageStart)
                    }
                }
                chains.append(
                    DyldSharedCacheChainedFixup(
                        segmentIndex: index,
                        segmentOffset: segmentVMOffset,
                        pageSize: pageSize,
                        pointerFormat: pointerFormat,
                        pageStarts: pageStarts
                    )
                )
            }
        }

        let count = min(Int(importsCount), maximumImports)
        guard count > 0, Int(symbolsOffset) < data.count else { return (chains, []) }
        var imports: [DyldSharedCacheFixupImport] = []
        let entrySize: Int
        switch importsFormat {
        case 1, 2:
            entrySize = 4
        case 3:
            entrySize = 8
        default:
            return (chains, [])
        }
        for index in 0..<count {
            let entryOffset = Int(importsOffset) + index * entrySize
            guard entryOffset + entrySize <= data.count else { break }
            var nameOffset: UInt64 = 0
            var libraryOrdinal: Int32 = 0
            var weak = false
            var addend: Int64 = 0
            if importsFormat == 3 {
                guard let raw = try? uint64(data, offset: entryOffset) else { continue }
                libraryOrdinal = Int32(raw & 0xffff)
                weak = ((raw >> 16) & 1) != 0
                nameOffset = raw >> 32
                if entryOffset + 16 <= data.count, let rawAddend = try? uint64(data, offset: entryOffset + 8) {
                    addend = Int64(bitPattern: rawAddend)
                }
            } else {
                guard let raw = try? uint32(data, offset: entryOffset) else { continue }
                libraryOrdinal = Int32(raw & 0xff)
                weak = ((raw >> 8) & 1) != 0
                nameOffset = UInt64(raw >> 9)
                if importsFormat == 2, entryOffset + 8 <= data.count,
                   let rawAddend = try? uint32(data, offset: entryOffset + 4) {
                    addend = Int64(Int32(bitPattern: rawAddend))
                }
            }
            guard let name = readDataCString(data, offset: Int(symbolsOffset) + Int(nameOffset)), !name.isEmpty else { continue }
            imports.append(DyldSharedCacheFixupImport(name: name, libraryOrdinal: libraryOrdinal, weakImport: weak, addend: addend))
        }
        return (chains, imports)
    }

    private static func parseRuntimeReferences(
        handle: FileHandle,
        sections: [(name: String, offset: UInt64, size: UInt64, address: UInt64)],
        imageFileOffset: UInt64,
        fileSize: UInt64
    ) throws -> [DyldSharedCacheRuntimeReference] {
        var references: [DyldSharedCacheRuntimeReference] = []
        for section in sections where isRuntimeReferenceSection(section.name) {
            guard let data = try readMachOData(handle: handle, rawOffset: section.offset, imageFileOffset: imageFileOffset, size: section.size, fileSize: fileSize) else { continue }
            var start = 0
            while start < data.count, references.count < 20_000 {
                let end = data[start...].firstIndex(of: 0) ?? data.endIndex
                let bytes = data[start..<end]
                if let value = String(data: bytes, encoding: .utf8), !value.isEmpty, value.allSatisfy({ $0.isASCII && !$0.isNewline }) {
                    let kind: String
                    if section.name == "__objc_methname" { kind = "objc-selector" }
                    else if section.name == "__objc_classname" { kind = "objc-class" }
                    else if section.name == "__objc_methtype" { kind = "objc-method-type" }
                    else { kind = "swift-metadata-string" }
                    references.append(
                        DyldSharedCacheRuntimeReference(
                            kind: kind,
                            section: section.name,
                            offset: section.address + UInt64(start),
                            value: value
                        )
                    )
                }
                start = end + 1
            }
        }
        return references.sorted { $0.offset == $1.offset ? $0.value < $1.value : $0.offset < $1.offset }
    }

    private static func parseCrossReferences(
        handle: FileHandle,
        sections: [(name: String, offset: UInt64, size: UInt64, address: UInt64)],
        targets: [DyldSharedCacheRuntimeReference],
        imageFileOffset: UInt64,
        fileSize: UInt64
    ) throws -> [DyldSharedCacheCrossReference] {
        guard !targets.isEmpty else { return [] }
        var references: [DyldSharedCacheCrossReference] = []
        let targetRanges = targets.compactMap { target -> (reference: DyldSharedCacheRuntimeReference, end: UInt64)? in
            let length = UInt64(target.value.utf8.count + 1)
            let (end, overflow) = target.offset.addingReportingOverflow(length)
            return overflow ? nil : (target, end)
        }
        for section in sections where !isRuntimeReferenceSection(section.name) {
            guard section.size >= 8, section.size <= 16 * 1024 * 1024,
                  let data = try readMachOData(handle: handle, rawOffset: section.offset, imageFileOffset: imageFileOffset, size: section.size, fileSize: fileSize) else { continue }
            var offset = 0
            while offset + 8 <= data.count, references.count < 20_000 {
                guard let pointer = try? uint64(data, offset: offset) else { break }
                if let target = targetRanges.first(where: { pointer >= $0.reference.offset && pointer < $0.end }) {
                    references.append(
                        DyldSharedCacheCrossReference(
                            sourceSection: section.name,
                            sourceAddress: section.address + UInt64(offset),
                            targetKind: target.reference.kind,
                            targetSection: target.reference.section,
                            targetAddress: target.reference.offset,
                            targetValue: target.reference.value
                        )
                    )
                }
                offset += 8
            }
        }
        return references.sorted {
            if $0.sourceAddress != $1.sourceAddress { return $0.sourceAddress < $1.sourceAddress }
            if $0.targetAddress != $1.targetAddress { return $0.targetAddress < $1.targetAddress }
            return $0.targetValue < $1.targetValue
        }
    }

    private static func isRuntimeReferenceSection(_ name: String) -> Bool {
        name == "__objc_methname" || name == "__objc_classname" || name == "__objc_methtype" || name == "__swift5_reflstr"
    }

    private static func readDataCString(_ data: Data, offset: Int) -> String? {
        guard offset >= 0, offset < data.count else { return nil }
        let end = data[offset...].firstIndex(of: 0) ?? data.endIndex
        return String(data: data[offset..<end], encoding: .utf8)
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

    private static func uint16(_ data: Data, offset: Int) throws -> UInt16 {
        guard offset >= 0, offset + 2 <= data.count else { throw DyldSharedCacheError.malformedHeader }
        return data[offset..<(offset + 2)].enumerated().reduce(UInt16(0)) { result, item in
            result | UInt16(item.element) << UInt16(item.offset * 8)
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

    private static func parseAddress(_ value: String) -> UInt64? {
        let normalized = value.hasPrefix("0x") ? String(value.dropFirst(2)) : value
        return UInt64(normalized, radix: 16)
    }
}
