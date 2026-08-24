// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct ObjectiveCMetadataReport: Codable, Equatable, Sendable {
    public let classes: [String]
    public let categories: [String]
    public let protocols: [String]
    public let selectors: [String]

    public init(classes: [String], categories: [String], protocols: [String], selectors: [String]) {
        self.classes = classes
        self.categories = categories
        self.protocols = protocols
        self.selectors = selectors
    }
}

public struct SwiftSymbolMetadata: Codable, Equatable, Sendable {
    public let mangled: String
    public let demangled: String

    public init(mangled: String, demangled: String) {
        self.mangled = mangled
        self.demangled = demangled
    }
}

public struct SwiftConcurrencyMetadata: Codable, Equatable, Sendable {
    public let asyncFunctions: [String]
    public let actors: [String]
    public let tasksAndContinuations: [String]

    public init(asyncFunctions: [String], actors: [String], tasksAndContinuations: [String]) {
        self.asyncFunctions = asyncFunctions
        self.actors = actors
        self.tasksAndContinuations = tasksAndContinuations
    }
}

public struct AppleRuntimeMetadataReport: Codable, Equatable, Sendable {
    public let path: String
    public let objectiveC: ObjectiveCMetadataReport
    public let swift: [SwiftSymbolMetadata]
    public let concurrency: SwiftConcurrencyMetadata

    public init(path: String, objectiveC: ObjectiveCMetadataReport, swift: [SwiftSymbolMetadata], concurrency: SwiftConcurrencyMetadata) {
        self.path = path
        self.objectiveC = objectiveC
        self.swift = swift
        self.concurrency = concurrency
    }
}

public enum AppleRuntimeMetadataService {
    public static func inspect(path: String, architecture: String? = nil) throws -> AppleRuntimeMetadataReport {
        let binary = try AppleBinaryIntelligenceService.inspect(path: path, architecture: architecture)
        var otoolArguments = ["otool", "-oV"]
        if let architecture { otoolArguments += ["-arch", architecture] }
        otoolArguments.append(path)
        let objectiveC = parseObjectiveC(try runXcrun(arguments: otoolArguments))

        let swiftNames = binary.symbols.compactMap { symbol -> String? in
            let candidate = symbol.name.hasPrefix("_")
                ? String(symbol.name.dropFirst())
                : symbol.name
            return candidate.hasPrefix("$s") || candidate.hasPrefix("$S") ? candidate : nil
        }
        let swift = try demangle(Array(Set(swiftNames)).sorted().prefix(2_000))
        return AppleRuntimeMetadataReport(
            path: path,
            objectiveC: objectiveC,
            swift: swift,
            concurrency: SwiftConcurrencyMetadata(
                asyncFunctions: swift.filter { $0.demangled.localizedCaseInsensitiveContains("async") }.map(\.demangled),
                actors: swift.filter { $0.demangled.localizedCaseInsensitiveContains("actor") }.map(\.demangled),
                tasksAndContinuations: swift.filter {
                    let value = $0.demangled.localizedLowercase
                    return value.contains("task") || value.contains("continuation") || value.contains("asyncstream")
                }.map(\.demangled)
            )
        )
    }

    private static func parseObjectiveC(_ output: String) -> ObjectiveCMetadataReport {
        var section = ""
        var classes = Set<String>()
        var categories = Set<String>()
        var protocols = Set<String>()
        var selectors = Set<String>()

        for line in output.split(whereSeparator: \.isNewline) {
            let raw = String(line)
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if raw.hasPrefix("Contents of (") {
                if let comma = raw.firstIndex(of: ","),
                   let end = raw[comma...].firstIndex(of: ")") {
                    section = String(raw[raw.index(after: comma)..<end])
                } else {
                    section = ""
                }
                continue
            }

            let indentation = raw.prefix { $0 == " " || $0 == "\t" }.count
            if section == "__objc_classlist",
               indentation <= 8,
               trimmed.hasPrefix("name "),
               let value = trimmed.split(whereSeparator: \.isWhitespace).last {
                let name = String(value)
                if !name.hasPrefix("_OBJC_") && name != "__mh_execute_header" {
                    classes.insert(name)
                }
            } else if section == "__objc_catlist",
                      indentation <= 8,
                      trimmed.hasPrefix("name "),
                      let value = trimmed.split(whereSeparator: \.isWhitespace).last {
                categories.insert(String(value))
            } else if section == "__objc_protolist",
                      indentation <= 12,
                      trimmed.hasPrefix("name "),
                      let value = trimmed.split(whereSeparator: \.isWhitespace).last {
                protocols.insert(String(value))
            } else if section == "__objc_selrefs",
                      trimmed.hasPrefix("0x") {
                let parts = trimmed.split(maxSplits: 1, whereSeparator: \.isWhitespace)
                if parts.count == 2 {
                    selectors.insert(String(parts[1]))
                }
            }
        }
        return ObjectiveCMetadataReport(
            classes: classes.sorted(),
            categories: categories.sorted(),
            protocols: protocols.sorted(),
            selectors: selectors.sorted()
        )
    }

    private static func demangle(_ names: ArraySlice<String>) throws -> [SwiftSymbolMetadata] {
        guard !names.isEmpty else { return [] }
        let values = Array(names)
        let output = try runXcrun(arguments: ["swift-demangle", "--compact"] + values)
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        return zip(values, lines).compactMap { mangled, demangled in
            let value = demangled.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, value != mangled else { return nil }
            return SwiftSymbolMetadata(mangled: mangled, demangled: value)
        }
    }

    private static func runXcrun(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-runtime-\(UUID().uuidString).stdout")
        let errorURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-runtime-\(UUID().uuidString).stderr")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        defer {
            try? FileManager.default.removeItem(at: outputURL)
            try? FileManager.default.removeItem(at: errorURL)
        }
        do {
            let outputHandle = try FileHandle(forWritingTo: outputURL)
            let errorHandle = try FileHandle(forWritingTo: errorURL)
            process.standardOutput = outputHandle
            process.standardError = errorHandle
            try process.run()
            process.waitUntilExit()
            try outputHandle.close()
            try errorHandle.close()
        } catch {
            throw AppleBinaryError.commandFailed(error.localizedDescription)
        }
        let stdout = try Data(contentsOf: outputURL)
        let stderr = try Data(contentsOf: errorURL)
        guard stdout.count <= 8 * 1024 * 1024, stderr.count <= 8 * 1024 * 1024 else {
            throw AppleBinaryError.outputTooLarge
        }
        guard process.terminationStatus == 0 else {
            throw AppleBinaryError.commandFailed(String(decoding: stderr, as: UTF8.self))
        }
        return String(decoding: stdout, as: UTF8.self)
    }
}
