// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum ControlFlowError: Error, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case inputNotFound
    case toolUnavailable
    case commandFailed(String)
    case outputTooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Control-flow analysis request is invalid or exceeds its bounded limits."
        case .inputNotFound:
            return "The Mach-O input for control-flow analysis was not found."
        case .toolUnavailable:
            return "llvm-objdump is unavailable in the selected Xcode toolchain."
        case .commandFailed(let message):
            return "Control-flow disassembly failed: \(message)"
        case .outputTooLarge:
            return "Control-flow disassembly exceeds the configured analysis limit."
        }
    }
}

public struct ControlFlowInstruction: Codable, Equatable, Sendable {
    public let address: String
    public let bytes: String
    public let mnemonic: String
    public let operands: String?
    public let branchKind: String?
    public let targetAddress: String?
    public let targetSymbol: String?

    public init(
        address: String,
        bytes: String,
        mnemonic: String,
        operands: String?,
        branchKind: String?,
        targetAddress: String?,
        targetSymbol: String?
    ) {
        self.address = address
        self.bytes = bytes
        self.mnemonic = mnemonic
        self.operands = operands
        self.branchKind = branchKind
        self.targetAddress = targetAddress
        self.targetSymbol = targetSymbol
    }
}

public struct ControlFlowBlock: Codable, Equatable, Sendable {
    public let startAddress: String
    public let endAddress: String
    public let instructionCount: Int
    public let successors: [String]

    public init(startAddress: String, endAddress: String, instructionCount: Int, successors: [String]) {
        self.startAddress = startAddress
        self.endAddress = endAddress
        self.instructionCount = instructionCount
        self.successors = successors
    }
}

public struct ControlFlowIndirectSymbol: Codable, Equatable, Sendable {
    public let section: String
    public let address: String
    public let index: Int
    public let name: String

    public init(section: String, address: String, index: Int, name: String) {
        self.section = section
        self.address = address
        self.index = index
        self.name = name
    }
}

public struct ControlFlowDataRange: Codable, Equatable, Sendable {
    public let offset: UInt64
    public let length: UInt64
    public let kind: String

    public init(offset: UInt64, length: UInt64, kind: String) {
        self.offset = offset
        self.length = length
        self.kind = kind
    }
}

public struct ControlFlowXref: Codable, Equatable, Sendable {
    public let fromAddress: String
    public let fromFunction: String?
    public let kind: String
    public let targetAddress: String?
    public let targetSymbol: String?

    public init(fromAddress: String, fromFunction: String?, kind: String, targetAddress: String?, targetSymbol: String?) {
        self.fromAddress = fromAddress
        self.fromFunction = fromFunction
        self.kind = kind
        self.targetAddress = targetAddress
        self.targetSymbol = targetSymbol
    }
}

public struct ControlFlowFunction: Codable, Equatable, Sendable {
    public let name: String
    public let startAddress: String
    public let endAddress: String
    public let blocks: [ControlFlowBlock]
    public let callees: [String]
    public let callers: [String]

    public init(
        name: String,
        startAddress: String,
        endAddress: String,
        blocks: [ControlFlowBlock],
        callees: [String],
        callers: [String]
    ) {
        self.name = name
        self.startAddress = startAddress
        self.endAddress = endAddress
        self.blocks = blocks
        self.callees = callees
        self.callers = callers
    }
}

public struct ControlFlowReport: Codable, Equatable, Sendable {
    public let path: String
    public let architecture: String
    public let instructions: [ControlFlowInstruction]
    public let functions: [ControlFlowFunction]
    public let externalCalls: [String]
    public let indirectSymbols: [ControlFlowIndirectSymbol]
    public let dataInCode: [ControlFlowDataRange]
    public let xrefs: [ControlFlowXref]

    public init(
        path: String,
        architecture: String,
        instructions: [ControlFlowInstruction],
        functions: [ControlFlowFunction],
        externalCalls: [String],
        indirectSymbols: [ControlFlowIndirectSymbol],
        dataInCode: [ControlFlowDataRange],
        xrefs: [ControlFlowXref]
    ) {
        self.path = path
        self.architecture = architecture
        self.instructions = instructions
        self.functions = functions
        self.externalCalls = externalCalls
        self.indirectSymbols = indirectSymbols
        self.dataInCode = dataInCode
        self.xrefs = xrefs
    }
}

public enum AppleControlFlowService {
    private static let maximumOutputSize = 16 * 1024 * 1024
    private static let maximumInstructions = 200_000
    private static let maximumFunctions = 20_000

    public static func analyze(path: String, architecture: String) throws -> ControlFlowReport {
        guard ["arm64", "arm64e", "x86_64"].contains(architecture),
              !path.isEmpty, path.utf8.count <= 4_096,
              !path.contains("\0"), URL(fileURLWithPath: path).path.hasPrefix("/") else {
            throw ControlFlowError.invalidRequest
        }
        guard FileManager.default.fileExists(atPath: path) else {
            throw ControlFlowError.inputNotFound
        }
        guard let objdump = ToolchainProbe.path(for: "llvm-objdump") else {
            throw ControlFlowError.toolUnavailable
        }

        let output = try runObjdump(executable: objdump, arguments: ["--macho", "--disassemble", "--arch=\(architecture)", path])
        let instructions = parseInstructions(output)
        guard !instructions.isEmpty else {
            throw ControlFlowError.commandFailed("No executable instructions were found for \(architecture).")
        }
        let functions = parseFunctions(path: path, architecture: architecture, instructions: instructions)
        let xrefs = parseXrefs(instructions: instructions, functions: functions)
        let indirectSymbols = parseIndirectSymbols(try runObjdump(executable: objdump, arguments: ["--macho", "--indirect-symbols", "--arch=\(architecture)", path]))
        let dataInCode = parseDataInCode(try runObjdump(executable: objdump, arguments: ["--macho", "--data-in-code", "--arch=\(architecture)", path]))
        return ControlFlowReport(
            path: path,
            architecture: architecture,
            instructions: instructions,
            functions: functions,
            externalCalls: functions.flatMap(\.callees).filter { !$0.hasPrefix("0x") }.sorted().reduce(into: []) { result, value in
                if !result.contains(value) { result.append(value) }
            },
            indirectSymbols: indirectSymbols,
            dataInCode: dataInCode,
            xrefs: xrefs
        )
    }

    private static func runObjdump(executable: String, arguments: [String]) throws -> String {
        let result: AppleProcessResult
        do {
            result = try AppleProcessRunner.run(executable: executable, arguments: arguments, maximumOutputSize: maximumOutputSize)
        } catch AppleProcessRunnerError.outputTooLarge { throw ControlFlowError.outputTooLarge }
        catch AppleProcessRunnerError.launchFailed(let message) { throw ControlFlowError.commandFailed(message) }
        catch { throw ControlFlowError.commandFailed(error.localizedDescription) }
        guard result.terminationStatus == 0 else {
            let message = String(decoding: result.stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw ControlFlowError.commandFailed(message.isEmpty ? "llvm-objdump failed." : message)
        }
        return String(decoding: result.stdout, as: UTF8.self)
    }

    private static func parseIndirectSymbols(_ output: String) -> [ControlFlowIndirectSymbol] {
        var section = ""
        var values: [ControlFlowIndirectSymbol] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let text = String(line)
            if let open = text.firstIndex(of: "("), let close = text.firstIndex(of: ")"), text.contains("Indirect symbols") {
                section = String(text[text.index(after: open)..<close])
                continue
            }
            let fields = text.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard fields.count >= 3, let address = parseAddress(fields[0]), let index = Int(fields[1]) else { continue }
            values.append(ControlFlowIndirectSymbol(section: section, address: formatAddress(address), index: index, name: fields.dropFirst(2).joined(separator: " ")))
        }
        return values
    }

    private static func parseDataInCode(_ output: String) -> [ControlFlowDataRange] {
        var values: [ControlFlowDataRange] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard fields.count >= 3, let offset = UInt64(fields[0], radix: 16), let length = UInt64(fields[1]) else { continue }
            values.append(ControlFlowDataRange(offset: offset, length: length, kind: fields.dropFirst(2).joined(separator: " ")))
        }
        return values
    }

    private static func parseInstructions(_ output: String) -> [ControlFlowInstruction] {
        var values: [ControlFlowInstruction] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let text = String(line)
            guard let colon = text.firstIndex(of: ":") else { continue }
            let address = String(text[..<colon]).trimmingCharacters(in: .whitespaces)
            guard isHex(address) else { continue }
            let fields = text[text.index(after: colon)...]
                .split(whereSeparator: { $0 == " " || $0 == "\t" })
                .map(String.init)
            guard let mnemonicIndex = fields.firstIndex(where: { !$0.isByteToken }) else { continue }
            let bytes = fields[..<mnemonicIndex].joined(separator: " ")
            let mnemonic = fields[mnemonicIndex]
            let operands = fields.dropFirst(mnemonicIndex + 1).joined(separator: " ")
            let branch = branchInfo(mnemonic: mnemonic, operands: operands)
            values.append(
                ControlFlowInstruction(
                    address: address,
                    bytes: bytes,
                    mnemonic: mnemonic,
                    operands: operands.isEmpty ? nil : operands,
                    branchKind: branch.kind,
                    targetAddress: branch.targetAddress,
                    targetSymbol: branch.targetSymbol
                )
            )
            if values.count >= maximumInstructions { break }
        }
        return values
    }

    private static func parseFunctions(
        path: String,
        architecture: String,
        instructions: [ControlFlowInstruction]
    ) -> [ControlFlowFunction] {
        let starts = functionStarts(path: path, architecture: architecture)
        let instructionAddresses = instructions.compactMap { UInt64($0.address, radix: 16) }
        let usableStarts = starts.isEmpty
            ? [instructionAddresses.first ?? 0]
            : starts.filter { start in instructionAddresses.contains(start) }
        var ranges: [(name: String, start: UInt64, end: UInt64)] = []
        for (index, start) in usableStarts.enumerated() {
            let next = index + 1 < usableStarts.count ? usableStarts[index + 1] : (instructionAddresses.last ?? start) + 4
            ranges.append((startsName(path: path, architecture: architecture, address: start) ?? "sub_\(String(start, radix: 16))", start, next))
        }
        if ranges.isEmpty, let first = instructionAddresses.first, let last = instructionAddresses.last {
            ranges = [("sub_\(String(first, radix: 16))", first, last + 4)]
        }

        var callEdges: [(from: String, to: String)] = []
        var functionValues: [ControlFlowFunction] = []
        for range in ranges.prefix(maximumFunctions) {
            let body = instructions.filter { instruction in
                guard let address = UInt64(instruction.address, radix: 16) else { return false }
                return address >= range.start && address < range.end
            }
            guard !body.isEmpty else { continue }
            let blocks = makeBlocks(body: body, functionEnd: range.end)
            var callees: [String] = []
            for instruction in body where instruction.branchKind?.hasSuffix("call") == true {
                let callee = instruction.targetSymbol ?? instruction.targetAddress ?? "unknown"
                if !callees.contains(callee) { callees.append(callee) }
                callEdges.append((range.name, callee))
            }
            functionValues.append(
                ControlFlowFunction(
                    name: range.name,
                    startAddress: formatAddress(range.start),
                    endAddress: formatAddress(range.end),
                    blocks: blocks,
                    callees: callees.sorted(),
                    callers: []
                )
            )
        }
        return functionValues.map { function in
            var updated = function
            updated = ControlFlowFunction(
                name: function.name,
                startAddress: function.startAddress,
                endAddress: function.endAddress,
                blocks: function.blocks,
                callees: function.callees,
                callers: callEdges.filter { $0.to == function.name || $0.to == function.startAddress }.map(\.from).sorted()
            )
            return updated
        }
    }

    private static func parseXrefs(instructions: [ControlFlowInstruction], functions: [ControlFlowFunction]) -> [ControlFlowXref] {
        instructions.compactMap { instruction in
            guard let kind = instruction.branchKind else { return nil }
            let address = parseAddress(instruction.address) ?? 0
            let function = functions.first {
                let start = parseAddress($0.startAddress) ?? UInt64.max
                let end = parseAddress($0.endAddress) ?? UInt64.min
                return address >= start && address < end
            }?.name
            guard instruction.targetAddress != nil || instruction.targetSymbol != nil || kind.hasPrefix("indirect") else { return nil }
            return ControlFlowXref(
                fromAddress: instruction.address.hasPrefix("0x") ? instruction.address : formatAddress(address),
                fromFunction: function,
                kind: kind,
                targetAddress: instruction.targetAddress,
                targetSymbol: instruction.targetSymbol
            )
        }
        .sorted {
            if $0.fromAddress != $1.fromAddress { return $0.fromAddress < $1.fromAddress }
            if $0.kind != $1.kind { return $0.kind < $1.kind }
            return ($0.targetAddress ?? $0.targetSymbol ?? "") < ($1.targetAddress ?? $1.targetSymbol ?? "")
        }
    }

    private static func makeBlocks(body: [ControlFlowInstruction], functionEnd: UInt64) -> [ControlFlowBlock] {
        guard !body.isEmpty else { return [] }
        let addresses = body.compactMap { UInt64($0.address, radix: 16) }
        var leaders = Set<UInt64>([addresses[0]])
        for (index, instruction) in body.enumerated() {
            guard let target = instruction.targetAddress.flatMap(parseAddress),
                  target >= addresses[0], target < functionEnd else { continue }
            leaders.insert(target)
            if instruction.branchKind == "conditional", index + 1 < addresses.count {
                leaders.insert(addresses[index + 1])
            }
        }
        let sortedLeaders = leaders.sorted()
        return sortedLeaders.enumerated().compactMap { index, start in
            let end = index + 1 < sortedLeaders.count ? sortedLeaders[index + 1] : functionEnd
            let blockInstructions = body.filter {
                guard let address = UInt64($0.address, radix: 16) else { return false }
                return address >= start && address < end
            }
            guard let last = blockInstructions.last else { return nil }
            var successors: [String] = []
            if let target = last.targetAddress, last.branchKind != "call" {
                successors.append(target)
            }
            if last.branchKind == "conditional",
               let address = parseAddress(last.address),
               let next = body.first(where: { parseAddress($0.address) ?? 0 > address }) {
                successors.append(next.address)
            } else if last.branchKind == nil,
                      last.mnemonic.lowercased() != "ret",
                      let address = parseAddress(last.address),
                      let next = body.first(where: { parseAddress($0.address) ?? 0 > address }) {
                successors.append(next.address)
            }
            return ControlFlowBlock(
                startAddress: formatAddress(start),
                endAddress: formatAddress(end),
                instructionCount: blockInstructions.count,
                successors: Array(Set(successors)).sorted()
            )
        }
    }

    private static func functionStarts(path: String, architecture: String) -> [UInt64] {
        guard let objdump = ToolchainProbe.path(for: "llvm-objdump"),
              let result = try? AppleProcessRunner.run(
                  executable: objdump,
                  arguments: ["--macho", "--function-starts=both", "--arch=\(architecture)", path],
                  maximumOutputSize: 2 * 1024 * 1024
              ), result.terminationStatus == 0 else { return [] }
        return String(decoding: result.stdout, as: UTF8.self).split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard let first = fields.first, first.allSatisfy(\.isHexDigit) else { return nil }
            return UInt64(first, radix: 16)
        }
    }

    private static func startsName(path: String, architecture: String, address: UInt64) -> String? {
        guard let objdump = ToolchainProbe.path(for: "llvm-objdump"),
              let result = try? AppleProcessRunner.run(
                  executable: objdump,
                  arguments: ["--macho", "--function-starts=both", "--arch=\(architecture)", path],
                  maximumOutputSize: 2 * 1024 * 1024
              ), result.terminationStatus == 0 else { return nil }
        for line in String(decoding: result.stdout, as: UTF8.self).split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard fields.count >= 2, UInt64(fields[0], radix: 16) == address else { continue }
            return fields.dropFirst().joined(separator: " ")
        }
        return nil
    }

    private static func branchInfo(mnemonic: String, operands: String) -> (kind: String?, targetAddress: String?, targetSymbol: String?) {
        let lower = mnemonic.lowercased()
        let target = firstHexAddress(in: operands)
        let targetSymbol: String?
        if let marker = operands.range(of: "symbol stub for:") {
            targetSymbol = operands[marker.upperBound...].trimmingCharacters(in: .whitespaces)
        } else {
            targetSymbol = nil
        }
        if lower == "bl" || lower == "blx" || lower.hasPrefix("call") {
            return ("call", target, targetSymbol)
        }
        if lower == "blr" {
            return ("indirect-call", nil, nil)
        }
        if lower == "br" {
            return ("indirect-branch", nil, nil)
        }
        if lower == "b" || lower == "jmp" || lower == "bra" {
            return ("unconditional", target, targetSymbol)
        }
        if lower.hasPrefix("b.") || lower.hasPrefix("j") || lower == "cbz" || lower == "cbnz" || lower == "tbz" || lower == "tbnz" {
            return ("conditional", target, targetSymbol)
        }
        return (nil, nil, nil)
    }

    private static func firstHexAddress(in text: String) -> String? {
        var token = ""
        for character in text {
            if character.isHexDigit || character == "x" {
                token.append(character)
            } else if token.hasPrefix("0x") {
                return token
            } else {
                token = ""
            }
        }
        return token.hasPrefix("0x") ? token : nil
    }

    private static func isHex(_ value: String) -> Bool {
        !value.isEmpty && value.allSatisfy(\.isHexDigit)
    }

    private static func formatAddress(_ address: UInt64) -> String {
        "0x\(String(address, radix: 16))"
    }

    private static func parseAddress(_ value: String) -> UInt64? {
        let normalized = value.hasPrefix("0x") ? String(value.dropFirst(2)) : value
        return UInt64(normalized, radix: 16)
    }
}

private extension String {
    var isByteToken: Bool {
        count == 2 && allSatisfy(\.isHexDigit)
    }
}
