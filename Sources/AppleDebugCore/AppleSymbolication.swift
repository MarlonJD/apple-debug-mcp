// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum SymbolicationError: Error, Equatable, LocalizedError, Sendable {
    case binaryNotFound
    case binaryNotRegularFile
    case unsupportedArtifact
    case invalidArchitecture
    case invalidAddress
    case invalidLoadAddress
    case addressOutOfRange
    case missingTextSegment
    case artifactChanged
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Symbolication binary was not found."
        case .binaryNotRegularFile:
            return "Symbolication input is not a regular file."
        case .unsupportedArtifact:
            return "Symbolication accepts a Mach-O file, an .app bundle, or a .dSYM bundle."
        case .invalidArchitecture:
            return "Requested symbolication architecture is not present in the artifact."
        case .invalidAddress:
            return "Symbolication address is not a valid hexadecimal address."
        case .invalidLoadAddress:
            return "Symbolication load address is missing or invalid."
        case .addressOutOfRange:
            return "Symbolication address is outside the selected Mach-O image range."
        case .missingTextSegment:
            return "Selected Mach-O slice does not contain a usable __TEXT segment."
        case .artifactChanged:
            return "Symbolication artifact changed after identity inspection."
        case .commandFailed(let message):
            return "atos symbolication failed: \(message)"
        }
    }
}

public enum SymbolicationStatus: String, Codable, Equatable, Sendable {
    case resolvedSourceLine
    case resolvedSymbolOnly
    case unresolved
}

public struct SymbolicationToolResult: Sendable {
    public let stdout: String
    public let stderr: String
    public let terminationStatus: Int32

    public init(stdout: String, stderr: String = "", terminationStatus: Int32 = 0) {
        self.stdout = stdout
        self.stderr = stderr
        self.terminationStatus = terminationStatus
    }
}

public struct SymbolicationToolRunner: Sendable {
    public let run: @Sendable (_ arguments: [String], _ timeoutMilliseconds: Int) throws -> SymbolicationToolResult

    public init(
        run: @escaping @Sendable (_ arguments: [String], _ timeoutMilliseconds: Int) throws -> SymbolicationToolResult
    ) {
        self.run = run
    }
}

public struct SymbolicationClock: Sendable {
    public let now: @Sendable () -> Double

    public init(now: @escaping @Sendable () -> Double) {
        self.now = now
    }

    public static let systemUptime = SymbolicationClock(now: {
        ProcessInfo.processInfo.systemUptime
    })
}

public struct SymbolicationAddressValidation: Codable, Equatable, Sendable {
    public let preferredTextAddress: UInt64
    public let runtimeBase: UInt64?
    public let slide: Int64?
    public let absoluteAddress: UInt64

    public init(
        preferredTextAddress: UInt64,
        runtimeBase: UInt64?,
        slide: Int64?,
        absoluteAddress: UInt64
    ) {
        self.preferredTextAddress = preferredTextAddress
        self.runtimeBase = runtimeBase
        self.slide = slide
        self.absoluteAddress = absoluteAddress
    }
}

public struct SymbolicationOutput: Codable, Equatable, Sendable {
    public let status: SymbolicationStatus
    public let symbol: String
    public let sourceFile: String?
    public let sourceLine: Int?
    public let diagnostic: String?

    public init(
        status: SymbolicationStatus,
        symbol: String,
        sourceFile: String? = nil,
        sourceLine: Int? = nil,
        diagnostic: String? = nil
    ) {
        self.status = status
        self.symbol = symbol
        self.sourceFile = sourceFile
        self.sourceLine = sourceLine
        self.diagnostic = diagnostic
    }
}

public struct SymbolicationResult: Codable, Equatable, Sendable {
    public let binaryPath: String
    public let architecture: String
    public let address: String
    public let loadAddress: String?
    public let symbol: String
    public let status: SymbolicationStatus
    public let sourceFile: String?
    public let sourceLine: Int?
    public let normalizedUUID: String?
    public let preferredTextAddress: String?
    public let runtimeBase: String?
    public let slide: String?
    public let diagnostic: String?

    public init(
        binaryPath: String,
        architecture: String,
        address: String,
        loadAddress: String?,
        symbol: String,
        status: SymbolicationStatus = .resolvedSymbolOnly,
        sourceFile: String? = nil,
        sourceLine: Int? = nil,
        normalizedUUID: String? = nil,
        preferredTextAddress: String? = nil,
        runtimeBase: String? = nil,
        slide: String? = nil,
        diagnostic: String? = nil
    ) {
        self.binaryPath = binaryPath
        self.architecture = architecture
        self.address = address
        self.loadAddress = loadAddress
        self.symbol = symbol
        self.status = status
        self.sourceFile = sourceFile
        self.sourceLine = sourceLine
        self.normalizedUUID = normalizedUUID
        self.preferredTextAddress = preferredTextAddress
        self.runtimeBase = runtimeBase
        self.slide = slide
        self.diagnostic = diagnostic
    }
}

public enum SymbolicationService {
    public static let maximumAtosOutputSize = 4 * 1024
    public static let maximumAtosTimeoutMilliseconds = 5_000

    public static func symbolize(
        binaryPath: String,
        architecture: String,
        address: String,
        loadAddress: String? = nil,
        toolRunner: SymbolicationToolRunner? = nil
    ) throws -> SymbolicationResult {
        guard let parsedAddress = parseAddress(address) else {
            throw SymbolicationError.invalidAddress
        }
        let parsedLoadAddress: UInt64?
        if let loadAddress {
            guard let value = parseAddress(loadAddress), value > 0 else {
                throw SymbolicationError.invalidLoadAddress
            }
            parsedLoadAddress = value
        } else {
            parsedLoadAddress = nil
        }
        let prepared = try prepare(path: binaryPath, architecture: architecture)
        let validation = try validateAddress(
            address: parsedAddress,
            loadAddress: parsedLoadAddress,
            slice: prepared.slice
        )
        guard AppleArtifactLayoutResolver.revalidate(prepared.layout.fileIdentity) else {
            throw SymbolicationError.artifactChanged
        }

        var arguments = [
            "atos",
            "-o", prepared.layout.resolvedBinaryPath,
            "-arch", architecture
        ]
        if let loadAddress {
            arguments += ["-l", loadAddress]
        }
        arguments.append(address)
        let result = try runTool(
            arguments: arguments,
            timeoutMilliseconds: maximumAtosTimeoutMilliseconds,
            runner: toolRunner
        )
        guard result.terminationStatus == 0 else {
            throw SymbolicationError.commandFailed(
                boundedDiagnostic(result.stderr.isEmpty ? result.stdout : result.stderr)
            )
        }
        let output = classifyAtosOutput(result.stdout, requestedAddress: address)
        return SymbolicationResult(
            binaryPath: binaryPath,
            architecture: architecture,
            address: address,
            loadAddress: loadAddress,
            symbol: output.symbol,
            status: output.status,
            sourceFile: output.sourceFile,
            sourceLine: output.sourceLine,
            normalizedUUID: prepared.slice.uuid,
            preferredTextAddress: hex(validation.preferredTextAddress),
            runtimeBase: validation.runtimeBase.map(hex),
            slide: validation.slide.map(String.init),
            diagnostic: output.diagnostic
        )
    }

    public static func validateAddress(
        address: UInt64,
        loadAddress: UInt64?,
        slice: MachOSliceReport
    ) throws -> SymbolicationAddressValidation {
        guard let preferredTextAddress = slice.preferredTextAddress,
              !slice.segments.isEmpty else {
            throw SymbolicationError.missingTextSegment
        }
        if let loadAddress {
            guard loadAddress > 0, loadAddress >= preferredTextAddress,
                  let signedSlide = Int64(exactly: loadAddress - preferredTextAddress) else {
                throw SymbolicationError.invalidLoadAddress
            }
            for segment in slice.segments where segment.virtualSize > 0 && segment.name != "__PAGEZERO" {
                guard let runtimeAddress = checkedAdd(segment.virtualAddress, signedSlide),
                      let runtimeEnd = checkedAdd(runtimeAddress, segment.virtualSize) else {
                    throw SymbolicationError.addressOutOfRange
                }
                if address >= runtimeAddress, address < runtimeEnd {
                    return SymbolicationAddressValidation(
                        preferredTextAddress: preferredTextAddress,
                        runtimeBase: loadAddress,
                        slide: signedSlide,
                        absoluteAddress: address
                    )
                }
            }
            throw SymbolicationError.addressOutOfRange
        }

        for segment in slice.segments where segment.virtualSize > 0 && segment.name != "__PAGEZERO" {
            guard let end = checkedAdd(segment.virtualAddress, segment.virtualSize) else {
                throw SymbolicationError.addressOutOfRange
            }
            if address >= segment.virtualAddress, address < end {
                return SymbolicationAddressValidation(
                    preferredTextAddress: preferredTextAddress,
                    runtimeBase: nil,
                    slide: nil,
                    absoluteAddress: address
                )
            }
        }
        throw SymbolicationError.addressOutOfRange
    }

    public static func classifyAtosOutput(
        _ output: String,
        requestedAddress: String
    ) -> SymbolicationOutput {
        let line = output
            .split(whereSeparator: \.isNewline)
            .first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !line.isEmpty else {
            return SymbolicationOutput(status: .unresolved, symbol: "", diagnostic: "atos returned no output.")
        }
        let normalizedRequested = requestedAddress.lowercased().hasPrefix("0x")
            ? String(requestedAddress.dropFirst(2)).lowercased()
            : requestedAddress.lowercased()
        let normalizedLine = line.lowercased().hasPrefix("0x")
            ? String(line.dropFirst(2)).lowercased()
            : line.lowercased()
        if line.contains("???") || line.localizedCaseInsensitiveContains("unresolved")
            || normalizedLine == normalizedRequested
            || (line.hasPrefix("0x") && UInt64(String(line.dropFirst(2)), radix: 16) != nil) {
            return SymbolicationOutput(status: .unresolved, symbol: line, diagnostic: "atos did not resolve the requested address.")
        }

        if let source = sourceLocation(in: line) {
            return SymbolicationOutput(
                status: .resolvedSourceLine,
                symbol: symbolPart(of: line),
                sourceFile: source.file,
                sourceLine: source.line
            )
        }
        if line.range(of: #"\(in\s+[^)]+\)"#, options: .regularExpression) != nil
            || line.range(of: #"^[A-Za-z_$?~:.<>][A-Za-z0-9_$?~:.<>]*$"#, options: .regularExpression) != nil {
            return SymbolicationOutput(status: .resolvedSymbolOnly, symbol: symbolPart(of: line))
        }
        return SymbolicationOutput(
            status: .unresolved,
            symbol: line,
            diagnostic: "atos output did not match a recognized symbolication form."
        )
    }

    private struct PreparedArtifact {
        let layout: AppleArtifactLayout
        let slice: MachOSliceReport
    }

    private static func prepare(path: String, architecture: String) throws -> PreparedArtifact {
        let layout: AppleArtifactLayout
        do {
            layout = try AppleArtifactLayoutResolver.resolve(path: path, architecture: architecture)
        } catch AppleArtifactLayoutError.fileNotFound {
            throw SymbolicationError.binaryNotFound
        } catch AppleArtifactLayoutError.notRegularFile {
            throw SymbolicationError.binaryNotRegularFile
        } catch AppleArtifactLayoutError.invalidPath,
                AppleArtifactLayoutError.unsupportedArtifact,
                AppleArtifactLayoutError.malformedBundle,
                AppleArtifactLayoutError.executableNotFound,
                AppleArtifactLayoutError.ambiguousDwarf,
                AppleArtifactLayoutError.symlinkEscapesBundle,
                AppleArtifactLayoutError.fileTooLarge,
                AppleArtifactLayoutError.tooManyDwarfEntries {
            throw SymbolicationError.unsupportedArtifact
        } catch AppleArtifactLayoutError.invalidArchitecture {
            throw SymbolicationError.invalidArchitecture
        } catch MachOError.invalidArchitecture {
            throw SymbolicationError.invalidArchitecture
        } catch MachOError.missingUUID,
                MachOError.duplicateUUID,
                MachOError.invalidUUID,
                MachOError.malformedLoadCommand,
                MachOError.malformedUniversalBinary,
                MachOError.overlappingSlices,
                MachOError.truncated,
                MachOError.unsupportedFormat {
            throw SymbolicationError.unsupportedArtifact
        }
        guard let slice = layout.slice(for: architecture) else {
            throw SymbolicationError.invalidArchitecture
        }
        return PreparedArtifact(layout: layout, slice: slice)
    }

    static func runTool(
        arguments: [String],
        timeoutMilliseconds: Int,
        runner: SymbolicationToolRunner?
    ) throws -> SymbolicationToolResult {
        if let runner {
            do {
                let result = try runner.run(arguments, timeoutMilliseconds)
                guard result.stdout.utf8.count <= maximumAtosOutputSize,
                      result.stderr.utf8.count <= maximumAtosOutputSize else {
                    throw SymbolicationError.commandFailed("atos output exceeds the 4 KiB batch limit.")
                }
                return result
            } catch let error as SymbolicationError {
                throw error
            } catch {
                throw SymbolicationError.commandFailed(boundedDiagnostic(error.localizedDescription))
            }
        }
        do {
            let result = try AppleProcessRunner.run(
                executable: "/usr/bin/xcrun",
                arguments: arguments,
                maximumOutputSize: maximumAtosOutputSize,
                timeoutMilliseconds: timeoutMilliseconds
            )
            return SymbolicationToolResult(
                stdout: String(decoding: result.stdout, as: UTF8.self),
                stderr: String(decoding: result.stderr, as: UTF8.self),
                terminationStatus: result.terminationStatus
            )
        } catch AppleProcessRunnerError.outputTooLarge {
            throw SymbolicationError.commandFailed("atos output exceeds the 4 KiB batch limit.")
        } catch AppleProcessRunnerError.timedOut {
            throw SymbolicationError.commandFailed("atos exceeded its 5 second batch deadline.")
        } catch AppleProcessRunnerError.launchFailed(let message) {
            throw SymbolicationError.commandFailed(message)
        } catch {
            throw SymbolicationError.commandFailed(error.localizedDescription)
        }
    }

    private static func parseAddress(_ value: String) -> UInt64? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, !normalized.hasPrefix("-") else { return nil }
        if normalized.lowercased().hasPrefix("0x") {
            return UInt64(normalized.dropFirst(2), radix: 16)
        }
        return UInt64(normalized, radix: 16)
    }

    private static func sourceLocation(in line: String) -> (file: String, line: Int)? {
        guard let expression = try? NSRegularExpression(pattern: #"([^()\s]+):(\d+)\)?$"#),
              let match = expression.firstMatch(
                  in: line,
                  range: NSRange(line.startIndex..., in: line)
              ),
              let fileRange = Range(match.range(at: 1), in: line),
              let lineRange = Range(match.range(at: 2), in: line),
              let lineNumber = Int(line[lineRange]) else {
            return nil
        }
        return (String(line[fileRange]), lineNumber)
    }

    private static func symbolPart(of line: String) -> String {
        if let range = line.range(of: " (in ") {
            return String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        if let range = line.range(of: " at ") {
            return String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        if let range = line.range(of: " (") {
            return String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return line
    }

    private static func checkedAdd(_ value: UInt64, _ signedValue: Int64) -> UInt64? {
        if signedValue >= 0 {
            return value.addingReportingOverflow(UInt64(signedValue)).overflow ? nil : value + UInt64(signedValue)
        }
        let magnitude = signedValue == Int64.min ? UInt64(Int64.max) + 1 : UInt64(-signedValue)
        return value >= magnitude ? value - magnitude : nil
    }

    private static func checkedAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64? {
        lhs.addingReportingOverflow(rhs).overflow ? nil : lhs + rhs
    }

    private static func boundedDiagnostic(_ value: String) -> String {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.utf8.count > maximumAtosOutputSize else { return text }
        let prefix = String(decoding: Array(text.utf8.prefix(maximumAtosOutputSize)), as: UTF8.self)
        return prefix + "..."
    }

    private static func hex(_ value: UInt64) -> String {
        String(format: "0x%llx", value)
    }
}
