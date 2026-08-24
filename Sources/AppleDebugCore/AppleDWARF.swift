// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum DWARFError: Error, Equatable, LocalizedError, Sendable {
    case inputNotFound
    case invalidRequest
    case commandFailed(String)
    case outputTooLarge

    public var errorDescription: String? {
        switch self {
        case .inputNotFound:
            return "DWARF input binary or dSYM was not found."
        case .invalidRequest:
            return "DWARF query is invalid or exceeds its bounded limits."
        case .commandFailed(let message):
            return "dwarfdump query failed: \(message)"
        case .outputTooLarge:
            return "dwarfdump output exceeds the configured analysis limit."
        }
    }
}

public struct DWARFEntry: Codable, Equatable, Sendable {
    public let offset: String
    public let tag: String
    public let depth: Int
    public let parentOffset: String?
    public let name: String?
    public let linkageName: String?
    public let declarationFile: String?
    public let declarationLine: Int?
    public let byteSize: Int?
    public let typeReference: String?
    public let attributes: [String: String]

    public init(
        offset: String,
        tag: String,
        depth: Int,
        parentOffset: String?,
        name: String?,
        linkageName: String?,
        declarationFile: String?,
        declarationLine: Int?,
        byteSize: Int?,
        typeReference: String?,
        attributes: [String: String]
    ) {
        self.offset = offset
        self.tag = tag
        self.depth = depth
        self.parentOffset = parentOffset
        self.name = name
        self.linkageName = linkageName
        self.declarationFile = declarationFile
        self.declarationLine = declarationLine
        self.byteSize = byteSize
        self.typeReference = typeReference
        self.attributes = attributes
    }
}

public struct DWARFLineEntry: Codable, Equatable, Sendable {
    public let tableOffset: String
    public let address: String
    public let line: Int
    public let column: Int
    public let fileIndex: Int
    public let isa: Int
    public let discriminator: Int
    public let opIndex: Int
    public let flags: [String]

    public init(
        tableOffset: String,
        address: String,
        line: Int,
        column: Int,
        fileIndex: Int,
        isa: Int,
        discriminator: Int,
        opIndex: Int,
        flags: [String]
    ) {
        self.tableOffset = tableOffset
        self.address = address
        self.line = line
        self.column = column
        self.fileIndex = fileIndex
        self.isa = isa
        self.discriminator = discriminator
        self.opIndex = opIndex
        self.flags = flags
    }
}

public struct DWARFReport: Codable, Equatable, Sendable {
    public let path: String
    public let architecture: String?
    public let nameQuery: String?
    public let lookupAddress: String?
    public let sources: [String]
    public let entries: [DWARFEntry]
    public let lineEntries: [DWARFLineEntry]
    public let statistics: DAPValue?
    public let lookupOutput: String?
    public let rawDebugInfo: String?

    public init(
        path: String,
        architecture: String?,
        nameQuery: String?,
        lookupAddress: String?,
        sources: [String],
        entries: [DWARFEntry],
        lineEntries: [DWARFLineEntry],
        statistics: DAPValue?,
        lookupOutput: String?,
        rawDebugInfo: String?
    ) {
        self.path = path
        self.architecture = architecture
        self.nameQuery = nameQuery
        self.lookupAddress = lookupAddress
        self.sources = sources
        self.entries = entries
        self.lineEntries = lineEntries
        self.statistics = statistics
        self.lookupOutput = lookupOutput
        self.rawDebugInfo = rawDebugInfo
    }
}

public enum DWARFService {
    private static let maximumOutputSize = 8 * 1024 * 1024
    private static let maximumEntries = 20_000
    private static let maximumSources = 20_000
    private static let maximumLineEntries = 50_000

    public static func inspect(
        path: String,
        architecture: String? = nil,
        name: String? = nil,
        lookupAddress: String? = nil,
        depth: Int = 3,
        includeSources: Bool = true,
        includeStatistics: Bool = true,
        includeLineTable: Bool = true,
        includeRaw: Bool = false
    ) throws -> DWARFReport {
        guard !path.isEmpty, path.utf8.count <= 4_096,
              !path.contains("\0"),
              depth > 0, depth <= 8,
              architecture.map({ !$0.isEmpty && $0.utf8.count <= 64 && !$0.contains("\0") }) ?? true,
              name.map({ !$0.isEmpty && $0.utf8.count <= 512 && !$0.contains("\0") }) ?? true,
              lookupAddress.map({ isHexAddress($0) }) ?? true else {
            throw DWARFError.invalidRequest
        }
        guard FileManager.default.fileExists(atPath: path) else {
            throw DWARFError.inputNotFound
        }
        guard ToolchainProbe.path(for: "dwarfdump") != nil else {
            throw DWARFError.commandFailed("dwarfdump is unavailable.")
        }

        var infoArguments = ["dwarfdump"]
        if let architecture { infoArguments.append("--arch=\(architecture)") }
        infoArguments += [
            "--debug-info",
            "--show-children",
            "--recurse-depth=\(depth)"
        ]
        if let name { infoArguments.append("--name=\(name)") }
        infoArguments.append(path)
        let infoOutput = try run(arguments: infoArguments)

        var sources: [String] = []
        if includeSources {
            var sourceArguments = ["dwarfdump"]
            if let architecture { sourceArguments.append("--arch=\(architecture)") }
            sourceArguments += ["--show-sources", path]
            sources = parseSources(try run(arguments: sourceArguments))
        }

        var statistics: DAPValue?
        if includeStatistics {
            var statisticsArguments = ["dwarfdump"]
            if let architecture { statisticsArguments.append("--arch=\(architecture)") }
            statisticsArguments += ["--statistics", path]
            let output = try run(arguments: statisticsArguments)
            statistics = try? JSONDecoder().decode(DAPValue.self, from: Data(output.utf8))
        }

        var lineEntries: [DWARFLineEntry] = []
        if includeLineTable {
            var lineArguments = ["dwarfdump"]
            if let architecture { lineArguments.append("--arch=\(architecture)") }
            lineArguments += ["--debug-line", path]
            lineEntries = parseLineEntries(try run(arguments: lineArguments))
        }

        var lookupOutput: String?
        if let lookupAddress {
            var lookupArguments = ["dwarfdump"]
            if let architecture { lookupArguments.append("--arch=\(architecture)") }
            lookupArguments += ["--lookup=\(lookupAddress)", path]
            lookupOutput = try run(arguments: lookupArguments)
        }

        return DWARFReport(
            path: path,
            architecture: architecture,
            nameQuery: name,
            lookupAddress: lookupAddress,
            sources: sources,
            entries: parseEntries(infoOutput),
            lineEntries: lineEntries,
            statistics: statistics,
            lookupOutput: lookupOutput,
            rawDebugInfo: includeRaw ? infoOutput : nil
        )
    }

    private static func run(arguments: [String]) throws -> String {
        guard let executable = ToolchainProbe.path(for: "dwarfdump") else {
            throw DWARFError.commandFailed("dwarfdump is unavailable.")
        }
        let result: AppleProcessResult
        do {
            result = try AppleProcessRunner.run(
                executable: executable,
                arguments: Array(arguments.dropFirst()),
                maximumOutputSize: maximumOutputSize
            )
        } catch AppleProcessRunnerError.outputTooLarge {
            throw DWARFError.outputTooLarge
        } catch AppleProcessRunnerError.launchFailed(let message) {
            throw DWARFError.commandFailed(message)
        } catch {
            throw DWARFError.commandFailed(error.localizedDescription)
        }
        guard result.terminationStatus == 0 else {
            let message = String(decoding: result.stderr, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw DWARFError.commandFailed(message.isEmpty ? "dwarfdump failed." : message)
        }
        return String(decoding: result.stdout, as: UTF8.self)
    }

    private static func parseEntries(_ output: String) -> [DWARFEntry] {
        var entries: [DWARFEntry] = []
        var current: MutableEntry?
        var offsetsByDepth: [String] = []

        func appendCurrent() {
            guard let current else { return }
            entries.append(
                DWARFEntry(
                    offset: current.offset,
                    tag: current.tag,
                    depth: current.depth,
                    parentOffset: current.parentOffset,
                    name: current.name,
                    linkageName: current.linkageName,
                    declarationFile: current.declarationFile,
                    declarationLine: current.declarationLine,
                    byteSize: current.byteSize,
                    typeReference: current.typeReference,
                    attributes: current.attributes
                )
            )
        }

        for line in output.split(whereSeparator: \.isNewline) {
            let text = String(line)
            if let colon = text.firstIndex(of: ":"),
               let marker = text.range(
                   of: "DW_TAG_",
                   range: text.index(after: colon)..<text.endIndex
               ) {
                appendCurrent()
                let indent = text[text.index(after: colon)..<marker.lowerBound]
                    .reduce(into: 0) { count, character in
                        if character == " " || character == "\t" { count += 1 }
                    }
                let depth = max(0, (indent - 1) / 2)
                offsetsByDepth = Array(offsetsByDepth.prefix(depth))
                let offset = String(text[..<colon]).trimmingCharacters(in: .whitespaces)
                let parentOffset = offsetsByDepth.last
                offsetsByDepth.append(offset)
                current = MutableEntry(
                    offset: offset,
                    tag: String(text[marker.lowerBound...]).trimmingCharacters(in: .whitespaces),
                    depth: depth,
                    parentOffset: parentOffset,
                    name: nil,
                    linkageName: nil,
                    declarationFile: nil,
                    declarationLine: nil,
                    byteSize: nil,
                    typeReference: nil,
                    attributes: [:]
                )
                if entries.count >= maximumEntries { break }
                continue
            }
            guard current != nil else { continue }
            guard let attribute = parseAttribute(text) else { continue }
            current?.attributes[attribute.name] = attribute.value
            switch attribute.name {
            case "DW_AT_name":
                current?.name = attribute.value
            case "DW_AT_linkage_name":
                current?.linkageName = attribute.value
            case "DW_AT_decl_file":
                current?.declarationFile = attribute.value
            case "DW_AT_decl_line":
                current?.declarationLine = integerAttribute(attribute.value)
            case "DW_AT_byte_size":
                current?.byteSize = integerAttribute(attribute.value)
            case "DW_AT_type":
                current?.typeReference = attribute.value
            default:
                break
            }
        }
        appendCurrent()
        return entries
    }

    private static func parseLineEntries(_ output: String) -> [DWARFLineEntry] {
        var entries: [DWARFLineEntry] = []
        var tableOffset = "0x0"
        for line in output.split(whereSeparator: \.isNewline) {
            let text = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            if text.hasPrefix("debug_line[") {
                let start = text.index(text.startIndex, offsetBy: "debug_line[".count)
                if let end = text[start...].firstIndex(of: "]") {
                    tableOffset = String(text[start..<end])
                }
                continue
            }
            let fields = text.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count >= 7,
                  fields[0].hasPrefix("0x"),
                  let lineNumber = parseInteger(String(fields[1])),
                  let column = parseInteger(String(fields[2])),
                  let fileIndex = parseInteger(String(fields[3])),
                  let isa = parseInteger(String(fields[4])),
                  let discriminator = parseInteger(String(fields[5])),
                  let opIndex = parseInteger(String(fields[6])) else { continue }
            entries.append(
                DWARFLineEntry(
                    tableOffset: tableOffset,
                    address: String(fields[0]),
                    line: lineNumber,
                    column: column,
                    fileIndex: fileIndex,
                    isa: isa,
                    discriminator: discriminator,
                    opIndex: opIndex,
                    flags: fields.dropFirst(7).map(String.init)
                )
            )
            if entries.count >= maximumLineEntries { break }
        }
        return entries
    }

    private static func parseSources(_ output: String) -> [String] {
        var values = Set<String>()
        for line in output.split(whereSeparator: \.isNewline) {
            let value = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, !value.contains("file format") else { continue }
            values.insert(value)
            if values.count >= maximumSources { break }
        }
        return values.sorted()
    }

    private static func parseAttribute(_ text: String) -> (name: String, value: String)? {
        guard let start = text.range(of: "DW_AT_") else { return nil }
        let suffix = text[start.lowerBound...]
        let end = suffix.firstIndex(where: { $0 == " " || $0 == "\t" || $0 == "(" }) ?? suffix.endIndex
        let name = String(suffix[..<end])
        guard let value = attributeValue(text) else { return nil }
        return (name, value)
    }

    private static func attributeValue(_ text: String) -> String? {
        guard let open = text.firstIndex(of: "("),
              let close = text.lastIndex(of: ")"),
              close > open else { return nil }
        var value = String(text[text.index(after: open)..<close])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
            value.removeFirst()
            value.removeLast()
        }
        return value.isEmpty ? nil : value
    }

    private static func integerAttribute(_ text: String) -> Int? {
        let value = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        if value.hasPrefix("0x") {
            return Int(value.dropFirst(2), radix: 16)
        }
        return parseInteger(value)
    }

    private static func parseInteger(_ value: String) -> Int? {
        if value.hasPrefix("0x") {
            return Int(value.dropFirst(2), radix: 16)
        }
        return Int(value)
    }

    private static func isHexAddress(_ value: String) -> Bool {
        let normalized = value.hasPrefix("0x") ? String(value.dropFirst(2)) : value
        return !normalized.isEmpty && UInt64(normalized, radix: 16) != nil
    }

    private struct MutableEntry {
        let offset: String
        let tag: String
        let depth: Int
        let parentOffset: String?
        var name: String?
        var linkageName: String?
        var declarationFile: String?
        var declarationLine: Int?
        var byteSize: Int?
        var typeReference: String?
        var attributes: [String: String]
    }
}
