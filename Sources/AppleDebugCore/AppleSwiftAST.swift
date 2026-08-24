// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum SwiftASTError: Error, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case inputNotFound
    case toolUnavailable
    case commandFailed(String)
    case outputTooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Swift AST request is invalid or exceeds its bounded limits."
        case .inputNotFound:
            return "The Swift source input was not found."
        case .toolUnavailable:
            return "swiftc is unavailable in the selected Xcode toolchain."
        case .commandFailed(let message):
            return "swiftc AST emission failed: \(message)"
        case .outputTooLarge:
            return "swiftc AST output exceeds the configured analysis limit."
        }
    }
}

public struct SwiftASTNode: Codable, Equatable, Sendable {
    public let kind: String
    public let name: String?
    public let type: String?
    public let location: String?
    public let depth: Int
    public let attributes: [String: String]

    public init(kind: String, name: String?, type: String?, location: String?, depth: Int, attributes: [String: String]) {
        self.kind = kind
        self.name = name
        self.type = type
        self.location = location
        self.depth = depth
        self.attributes = attributes
    }
}

public struct SwiftASTReport: Codable, Equatable, Sendable {
    public let path: String
    public let moduleName: String
    public let nodeCount: Int
    public let declarationCount: Int
    public let typeCount: Int
    public let functionCount: Int
    public let variableCount: Int
    public let importCount: Int
    public let nodes: [SwiftASTNode]
    public let declarations: [String]
    public let types: [String]
    public let functions: [String]
    public let variables: [String]
    public let imports: [String]
    public let rawAST: String?
    public let notes: [String]

    public init(path: String, moduleName: String, nodeCount: Int, declarationCount: Int, typeCount: Int, functionCount: Int, variableCount: Int, importCount: Int, nodes: [SwiftASTNode], declarations: [String], types: [String], functions: [String], variables: [String], imports: [String], rawAST: String?, notes: [String]) {
        self.path = path
        self.moduleName = moduleName
        self.nodeCount = nodeCount
        self.declarationCount = declarationCount
        self.typeCount = typeCount
        self.functionCount = functionCount
        self.variableCount = variableCount
        self.importCount = importCount
        self.nodes = nodes
        self.declarations = declarations
        self.types = types
        self.functions = functions
        self.variables = variables
        self.imports = imports
        self.rawAST = rawAST
        self.notes = notes
    }
}

public enum SwiftASTService {
    private static let maximumSourceSize = 2 * 1024 * 1024
    private static let maximumOutputSize = 16 * 1024 * 1024
    private static let maximumNodes = 100_000

    public static func inspect(
        path: String,
        moduleName: String = "AppleDebugSource",
        includeRaw: Bool = false
    ) throws -> SwiftASTReport {
        guard !path.isEmpty, path.utf8.count <= 4_096,
              !path.contains("\0"), path.hasSuffix(".swift"),
              URL(fileURLWithPath: path).path.hasPrefix("/"),
              validModuleName(moduleName) else {
            throw SwiftASTError.invalidRequest
        }
        guard FileManager.default.fileExists(atPath: path) else { throw SwiftASTError.inputNotFound }
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard let size = attributes[.size] as? NSNumber, size.intValue <= maximumSourceSize else {
            throw SwiftASTError.invalidRequest
        }
        guard ToolchainProbe.path(for: "swiftc") != nil else { throw SwiftASTError.toolUnavailable }
        let result: AppleProcessResult
        do {
            result = try AppleProcessRunner.run(
                executable: "/usr/bin/xcrun",
                arguments: ["swiftc", "-dump-ast", "-parse-as-library", "-module-name", moduleName, path],
                maximumOutputSize: maximumOutputSize
            )
        } catch AppleProcessRunnerError.outputTooLarge {
            throw SwiftASTError.outputTooLarge
        } catch AppleProcessRunnerError.launchFailed(let message) {
            throw SwiftASTError.commandFailed(message)
        } catch {
            throw SwiftASTError.commandFailed(error.localizedDescription)
        }
        guard result.terminationStatus == 0 else {
            let message = String(decoding: result.stderr, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw SwiftASTError.commandFailed(message.isEmpty ? "swiftc failed." : message)
        }
        let raw = String(decoding: result.stdout, as: UTF8.self)
        let nodes = parseNodes(raw)
        let declarations = uniqueNames(nodes.filter { $0.kind.hasSuffix("_decl") && $0.kind != "import_decl" })
        let types = uniqueNames(nodes.filter { ["struct_decl", "class_decl", "enum_decl", "protocol_decl", "actor_decl", "typealias_decl"].contains($0.kind) })
        let functions = uniqueNames(nodes.filter { ["func_decl", "constructor_decl", "destructor_decl", "accessor_decl"].contains($0.kind) })
        let variables = uniqueNames(nodes.filter { ["var_decl", "pattern_binding_decl", "param_decl"].contains($0.kind) })
        let imports = uniqueNames(nodes.filter { $0.kind == "import_decl" })
        return SwiftASTReport(
            path: path,
            moduleName: moduleName,
            nodeCount: nodes.count,
            declarationCount: declarations.count,
            typeCount: types.count,
            functionCount: functions.count,
            variableCount: variables.count,
            importCount: imports.count,
            nodes: nodes,
            declarations: declarations,
            types: types,
            functions: functions,
            variables: variables,
            imports: imports,
            rawAST: includeRaw ? raw : nil,
            notes: [
                "This report is source-backed public swiftc -dump-ast output; compiled binaries without source are covered by Mach-O, Swift metadata, and DWARF tools instead.",
                "AST nodes and compiler output are bounded; no private compiler database or runtime state is accessed."
            ]
        )
    }

    private static func parseNodes(_ raw: String) -> [SwiftASTNode] {
        var nodes: [SwiftASTNode] = []
        for line in raw.split(whereSeparator: \.isNewline) {
            guard nodes.count < maximumNodes else { break }
            let source = String(line)
            let leadingSpaces = source.prefix { $0 == " " || $0 == "\t" }.count
            let text = source.dropFirst(leadingSpaces)
            guard text.first == "(", text.count > 1 else { continue }
            let body = text.dropFirst()
            guard let kind = body.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == ")" }).first,
                  !kind.isEmpty else { continue }
            let kindString = String(kind)
            var attributes: [String: String] = [:]
            for key in ["interface_type", "type", "inherits", "access", "module", "decl"] {
                if let value = quotedAttribute(String(body), key: key) { attributes[key] = value }
            }
            let name: String?
            if kindString == "import_decl", let module = attributes["module"] {
                name = module
            } else {
                name = firstQuotedValue(String(body))
            }
            let type = attributes["interface_type"] ?? attributes["type"]
            let location = rangeAttribute(String(body))
            nodes.append(
                SwiftASTNode(
                    kind: kindString,
                    name: name,
                    type: type,
                    location: location,
                    depth: leadingSpaces / 2,
                    attributes: attributes
                )
            )
        }
        return nodes
    }

    private static func uniqueNames(_ nodes: [SwiftASTNode]) -> [String] {
        Array(Set(nodes.compactMap(\.name))).sorted()
    }

    private static func validModuleName(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 256 && value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    private static func firstQuotedValue(_ text: String) -> String? {
        guard let start = text.firstIndex(of: "\"") else { return nil }
        let valueStart = text.index(after: start)
        guard let end = text[valueStart...].firstIndex(of: "\"") else { return nil }
        let value = String(text[valueStart..<end])
        return value.isEmpty ? nil : value
    }

    private static func quotedAttribute(_ text: String, key: String) -> String? {
        guard let keyRange = text.range(of: "\(key)=\"") else { return nil }
        let valueStart = keyRange.upperBound
        guard let end = text[valueStart...].firstIndex(of: "\"") else { return nil }
        return String(text[valueStart..<end])
    }

    private static func rangeAttribute(_ text: String) -> String? {
        guard let start = text.range(of: "range=[")?.lowerBound,
              let end = text[start...].firstIndex(of: "]") else { return nil }
        return String(text[start...end])
    }
}
