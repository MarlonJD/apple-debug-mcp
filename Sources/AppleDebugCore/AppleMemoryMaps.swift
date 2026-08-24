// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct AppleMemoryRegion: Codable, Equatable, Sendable {
    public let regionType: String
    public let startAddress: String
    public let endAddress: String
    public let virtualSizeBytes: UInt64
    public let residentBytes: UInt64
    public let dirtyBytes: UInt64
    public let swappedBytes: UInt64
    public let permissions: String
    public let shareMode: String?
    public let detail: String?

    public init(
        regionType: String,
        startAddress: String,
        endAddress: String,
        virtualSizeBytes: UInt64,
        residentBytes: UInt64,
        dirtyBytes: UInt64,
        swappedBytes: UInt64,
        permissions: String,
        shareMode: String?,
        detail: String?
    ) {
        self.regionType = regionType
        self.startAddress = startAddress
        self.endAddress = endAddress
        self.virtualSizeBytes = virtualSizeBytes
        self.residentBytes = residentBytes
        self.dirtyBytes = dirtyBytes
        self.swappedBytes = swappedBytes
        self.permissions = permissions
        self.shareMode = shareMode
        self.detail = detail
    }
}

public struct AppleMemoryMapReport: Codable, Equatable, Sendable {
    public let processID: Int
    public let regions: [AppleMemoryRegion]
    public let rawOutput: String?

    public init(processID: Int, regions: [AppleMemoryRegion], rawOutput: String?) {
        self.processID = processID
        self.regions = regions
        self.rawOutput = rawOutput
    }
}

public struct AppleMemoryRegionChange: Codable, Equatable, Sendable {
    public let identity: String
    public let before: AppleMemoryRegion?
    public let after: AppleMemoryRegion?

    public init(identity: String, before: AppleMemoryRegion?, after: AppleMemoryRegion?) {
        self.identity = identity
        self.before = before
        self.after = after
    }
}

public struct AppleMemoryMapDiff: Codable, Equatable, Sendable {
    public let leftProcessID: Int
    public let rightProcessID: Int
    public let added: [AppleMemoryRegion]
    public let removed: [AppleMemoryRegion]
    public let changed: [AppleMemoryRegionChange]

    public init(
        leftProcessID: Int,
        rightProcessID: Int,
        added: [AppleMemoryRegion],
        removed: [AppleMemoryRegion],
        changed: [AppleMemoryRegionChange]
    ) {
        self.leftProcessID = leftProcessID
        self.rightProcessID = rightProcessID
        self.added = added
        self.removed = removed
        self.changed = changed
    }
}

public struct AppleMemorySnapshotResult: Codable, Equatable, Sendable {
    public let path: String
    public let report: AppleMemoryMapReport

    public init(path: String, report: AppleMemoryMapReport) {
        self.path = path
        self.report = report
    }
}

public enum AppleMemoryMapServiceError: Error, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case permissionDisabled
    case toolUnavailable
    case commandFailed(String)
    case outputTooLarge
    case snapshotNotFound
    case invalidSnapshot

    public var errorDescription: String? {
        switch self {
        case .invalidRequest: return "Memory-map request is invalid or exceeds its bounded limits."
        case .permissionDisabled: return "Memory-map capture requires APPLE_DEBUG_ALLOW_TARGET_ATTACH=1."
        case .toolUnavailable: return "vmmap is unavailable in the selected Apple toolchain."
        case .commandFailed(let message): return "vmmap failed: \(message)"
        case .outputTooLarge: return "vmmap output exceeds the configured analysis limit."
        case .snapshotNotFound: return "Memory snapshot file was not found."
        case .invalidSnapshot: return "Memory snapshot JSON is invalid."
        }
    }
}

public enum AppleMemoryMapService {
    private static let maximumOutputSize = 8 * 1024 * 1024
    private static let maximumRegions = 100_000

    public static func capture(processID: Int, includeRawOutput: Bool = false) throws -> AppleMemoryMapReport {
        guard processID > 0 else { throw AppleMemoryMapServiceError.invalidRequest }
        do {
            try DebugPolicy.validateAttach(processID: processID)
        } catch DebugPolicyError.attachDisabled {
            throw AppleMemoryMapServiceError.permissionDisabled
        } catch {
            throw AppleMemoryMapServiceError.invalidRequest
        }
        guard let vmmap = ToolchainProbe.path(for: "vmmap") else {
            throw AppleMemoryMapServiceError.toolUnavailable
        }
        let result: AppleProcessResult
        do {
            result = try AppleProcessRunner.run(
                executable: vmmap,
                arguments: ["-wide", "-interleaved", String(processID)],
                maximumOutputSize: maximumOutputSize
            )
        } catch AppleProcessRunnerError.outputTooLarge {
            throw AppleMemoryMapServiceError.outputTooLarge
        } catch AppleProcessRunnerError.launchFailed(let message) {
            throw AppleMemoryMapServiceError.commandFailed(message)
        } catch {
            throw AppleMemoryMapServiceError.commandFailed(error.localizedDescription)
        }
        guard result.terminationStatus == 0 else {
            let message = String(decoding: result.stderr, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw AppleMemoryMapServiceError.commandFailed(message.isEmpty ? "vmmap failed." : message)
        }
        let raw = String(decoding: result.stdout, as: UTF8.self)
        return AppleMemoryMapReport(processID: processID, regions: parse(raw), rawOutput: includeRawOutput ? raw : nil)
    }

    public static func saveSnapshot(
        processID: Int,
        outputPath: String,
        includeRawOutput: Bool = false
    ) throws -> AppleMemorySnapshotResult {
        guard validOutputPath(outputPath) else { throw AppleMemoryMapServiceError.invalidRequest }
        let report = try capture(processID: processID, includeRawOutput: includeRawOutput)
        do {
            try JSONEncoder().encode(report).write(to: URL(fileURLWithPath: outputPath), options: .atomic)
        } catch {
            throw AppleMemoryMapServiceError.commandFailed(error.localizedDescription)
        }
        return AppleMemorySnapshotResult(path: outputPath, report: report)
    }

    public static func diff(leftPath: String, rightPath: String) throws -> AppleMemoryMapDiff {
        guard validInputPath(leftPath), validInputPath(rightPath) else {
            throw AppleMemoryMapServiceError.invalidRequest
        }
        let left = try loadSnapshot(leftPath)
        let right = try loadSnapshot(rightPath)
        let leftMap = Dictionary(uniqueKeysWithValues: left.regions.map { (identity($0), $0) })
        let rightMap = Dictionary(uniqueKeysWithValues: right.regions.map { (identity($0), $0) })
        let leftKeys = Set(leftMap.keys)
        let rightKeys = Set(rightMap.keys)
        let added = rightKeys.subtracting(leftKeys).compactMap { rightMap[$0] }.sorted { $0.startAddress < $1.startAddress }
        let removed = leftKeys.subtracting(rightKeys).compactMap { leftMap[$0] }.sorted { $0.startAddress < $1.startAddress }
        let changed = leftKeys.intersection(rightKeys).compactMap { key -> AppleMemoryRegionChange? in
            guard let before = leftMap[key], let after = rightMap[key], before != after else { return nil }
            return AppleMemoryRegionChange(identity: key, before: before, after: after)
        }.sorted { $0.identity < $1.identity }
        return AppleMemoryMapDiff(
            leftProcessID: left.processID,
            rightProcessID: right.processID,
            added: added,
            removed: removed,
            changed: changed
        )
    }

    private static func parse(_ output: String) -> [AppleMemoryRegion] {
        var regions: [AppleMemoryRegion] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard let rangeIndex = fields.firstIndex(where: isAddressRange),
                  rangeIndex >= 1,
                  rangeIndex + 7 < fields.count else { continue }
            let range = fields[rangeIndex].split(separator: "-", maxSplits: 1).map(String.init)
            guard range.count == 2,
                  parseAddress(range[0]) != nil,
                  parseAddress(range[1]) != nil else { continue }
            let regionType = fields[..<rangeIndex].joined(separator: " ")
            let detailStart = rangeIndex + 9
            regions.append(
                AppleMemoryRegion(
                    regionType: regionType,
                    startAddress: "0x\(range[0])",
                    endAddress: "0x\(range[1])",
                    virtualSizeBytes: parseSize(fields[rangeIndex + 2]),
                    residentBytes: parseSize(fields[rangeIndex + 3]),
                    dirtyBytes: parseSize(fields[rangeIndex + 4]),
                    swappedBytes: parseSize(fields[rangeIndex + 5]),
                    permissions: fields[rangeIndex + 7],
                    shareMode: fields.count > rangeIndex + 8 ? fields[rangeIndex + 8] : nil,
                    detail: detailStart < fields.count ? fields[detailStart...].joined(separator: " ") : nil
                )
            )
            if regions.count >= maximumRegions { break }
        }
        return regions
    }

    private static func isAddressRange(_ field: String) -> Bool {
        let parts = field.split(separator: "-", maxSplits: 1)
        return parts.count == 2 && parseAddress(String(parts[0])) != nil && parseAddress(String(parts[1])) != nil
    }

    private static func parseAddress(_ value: String) -> UInt64? {
        UInt64(value.hasPrefix("0x") ? String(value.dropFirst(2)) : value, radix: 16)
    }

    private static func parseSize(_ value: String) -> UInt64 {
        let normalized = value.replacingOccurrences(of: ",", with: "")
        let suffix = normalized.last.map(String.init) ?? ""
        let number = Double(suffix == "K" || suffix == "M" || suffix == "G" ? String(normalized.dropLast()) : normalized) ?? 0
        let multiplier: Double = suffix == "K" ? 1_024 : suffix == "M" ? 1_048_576 : suffix == "G" ? 1_073_741_824 : 1
        return UInt64(max(0, number * multiplier))
    }

    private static func identity(_ region: AppleMemoryRegion) -> String {
        "\(region.startAddress)-\(region.endAddress)|\(region.regionType)|\(region.detail ?? "")"
    }

    private static func validOutputPath(_ path: String) -> Bool {
        !path.isEmpty && path.utf8.count <= 4_096 && !path.contains("\0") && path.hasSuffix(".json") &&
            URL(fileURLWithPath: path).path.hasPrefix("/") && !FileManager.default.fileExists(atPath: path)
    }

    private static func validInputPath(_ path: String) -> Bool {
        !path.isEmpty && path.utf8.count <= 4_096 && !path.contains("\0") && path.hasSuffix(".json") &&
            URL(fileURLWithPath: path).path.hasPrefix("/") && FileManager.default.fileExists(atPath: path)
    }

    private static func loadSnapshot(_ path: String) throws -> AppleMemoryMapReport {
        do { return try JSONDecoder().decode(AppleMemoryMapReport.self, from: Data(contentsOf: URL(fileURLWithPath: path))) }
        catch { throw AppleMemoryMapServiceError.invalidSnapshot }
    }
}
