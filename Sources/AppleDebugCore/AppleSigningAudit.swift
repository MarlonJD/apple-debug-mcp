// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct AppleSigningAudit: Codable, Equatable, Sendable {
    public let path: String
    public let verificationSucceeded: Bool
    public let identifier: String?
    public let teamIdentifier: String?
    public let format: String?
    public let codeDirectory: String?
    public let cdHash: String?
    public let entitlements: DAPValue?
    public let getTaskAllow: Bool?
    public let hardenedRuntime: Bool?
    public let authorities: [String]
    public let spctlAssessment: String?
    public let provisioningProfile: DAPValue?
    public let diagnostics: String

    public init(
        path: String,
        verificationSucceeded: Bool,
        identifier: String?,
        teamIdentifier: String?,
        format: String?,
        codeDirectory: String?,
        cdHash: String?,
        entitlements: DAPValue?,
        getTaskAllow: Bool?,
        hardenedRuntime: Bool?,
        authorities: [String],
        spctlAssessment: String?,
        provisioningProfile: DAPValue?,
        diagnostics: String
    ) {
        self.path = path
        self.verificationSucceeded = verificationSucceeded
        self.identifier = identifier
        self.teamIdentifier = teamIdentifier
        self.format = format
        self.codeDirectory = codeDirectory
        self.cdHash = cdHash
        self.entitlements = entitlements
        self.getTaskAllow = getTaskAllow
        self.hardenedRuntime = hardenedRuntime
        self.authorities = authorities
        self.spctlAssessment = spctlAssessment
        self.provisioningProfile = provisioningProfile
        self.diagnostics = diagnostics
    }
}

public enum AppleSigningAuditError: Error, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case inputNotFound
    case toolUnavailable
    case commandFailed(String)
    case outputTooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidRequest: return "Signing audit request is invalid or exceeds its bounded limits."
        case .inputNotFound: return "The signing audit input was not found."
        case .toolUnavailable: return "codesign or the Apple signing audit toolchain is unavailable."
        case .commandFailed(let message): return "Signing audit command failed: \(message)"
        case .outputTooLarge: return "Signing audit output exceeds the configured limit."
        }
    }
}

public enum AppleSigningAuditService {
    private static let maximumOutput = 4 * 1024 * 1024

    public static func inspect(path: String) throws -> AppleSigningAudit {
        guard !path.isEmpty, path.utf8.count <= 4_096, !path.contains("\0"), URL(fileURLWithPath: path).path.hasPrefix("/") else {
            throw AppleSigningAuditError.invalidRequest
        }
        guard FileManager.default.fileExists(atPath: path) else { throw AppleSigningAuditError.inputNotFound }
        let codesign = ToolchainProbe.path(for: "codesign")
            ?? (FileManager.default.fileExists(atPath: "/usr/bin/codesign") ? "/usr/bin/codesign" : nil)
        guard let codesign else { throw AppleSigningAuditError.toolUnavailable }

        let verification = try run(codesign, ["--verify", "--deep", "--strict", path], allowFailure: true)
        let details = try run(codesign, ["-d", "--verbose=4", path], allowFailure: true)
        let entitlementResult = try run(codesign, ["-d", "--entitlements", ":-", path], allowFailure: true)
        let verbose = [details.stderr, details.stdout].joined(separator: "\n")
        let entitlements = parsePlist(entitlementResult.stdout)
        let provisioningProfile = embeddedProfile(path: path)
        let spctlAssessment = runSpctl(path: path)
        let diagnostics = [verification.stderr, verification.stdout, details.stderr, spctlAssessment ?? ""]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return AppleSigningAudit(
            path: path,
            verificationSucceeded: verification.status == 0,
            identifier: value("Identifier", in: verbose),
            teamIdentifier: value("TeamIdentifier", in: verbose),
            format: value("Format", in: verbose),
            codeDirectory: value("CodeDirectory", in: verbose),
            cdHash: value("CDHash", in: verbose),
            entitlements: entitlements,
            getTaskAllow: boolValue(entitlements, key: "com.apple.security.get-task-allow"),
            hardenedRuntime: verbose.split(whereSeparator: \.isNewline).contains { $0.localizedCaseInsensitiveContains("(runtime)") },
            authorities: lines(prefix: "Authority=", in: verbose).map { String($0.dropFirst("Authority=".count)) },
            spctlAssessment: spctlAssessment,
            provisioningProfile: provisioningProfile,
            diagnostics: diagnostics
        )
    }

    private struct CommandResult { let stdout: String; let stderr: String; let status: Int32 }

    private static func run(_ executable: String, _ arguments: [String], allowFailure: Bool) throws -> CommandResult {
        let result: AppleProcessResult
        do {
            result = try AppleProcessRunner.run(executable: executable, arguments: arguments, maximumOutputSize: maximumOutput)
        } catch AppleProcessRunnerError.outputTooLarge { throw AppleSigningAuditError.outputTooLarge }
        catch AppleProcessRunnerError.launchFailed(let message) { throw AppleSigningAuditError.commandFailed(message) }
        catch { throw AppleSigningAuditError.commandFailed(error.localizedDescription) }
        let value = CommandResult(
            stdout: String(decoding: result.stdout, as: UTF8.self),
            stderr: String(decoding: result.stderr, as: UTF8.self),
            status: result.terminationStatus
        )
        if !allowFailure && result.terminationStatus != 0 { throw AppleSigningAuditError.commandFailed(value.stderr) }
        return value
    }

    private static func runSpctl(path: String) -> String? {
        guard FileManager.default.fileExists(atPath: "/usr/sbin/spctl"),
              let result = try? run("/usr/sbin/spctl", ["--assess", "--type", "execute", "--verbose=4", path], allowFailure: true) else { return nil }
        return [result.stderr, result.stdout].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func value(_ key: String, in text: String) -> String? {
        text.split(whereSeparator: \.isNewline).first { $0.hasPrefix("\(key)=") }.map { String($0.dropFirst(key.count + 1)) }
    }

    private static func lines(prefix: String, in text: String) -> [Substring] {
        text.split(whereSeparator: \.isNewline).filter { $0.hasPrefix(prefix) }
    }

    private static func parsePlist(_ text: String) -> DAPValue? {
        guard let start = text.firstIndex(of: "<"), let data = String(text[start...]).data(using: .utf8),
              let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else { return nil }
        return convert(object)
    }

    private static func embeddedProfile(path: String) -> DAPValue? {
        let url = URL(fileURLWithPath: path).appendingPathComponent("embedded.mobileprovision")
        guard FileManager.default.fileExists(atPath: url.path),
              FileManager.default.fileExists(atPath: "/usr/bin/security"),
              let result = try? run("/usr/bin/security", ["cms", "-D", "-i", url.path], allowFailure: true), result.status == 0 else { return nil }
        return parsePlist(result.stdout)
    }

    private static func boolValue(_ value: DAPValue?, key: String) -> Bool? {
        guard case .object(let object) = value else { return nil }
        guard case .boolean(let result) = object[key] else { return nil }
        return result
    }

    private static func convert(_ value: Any) -> DAPValue {
        if let dictionary = value as? [String: Any] { return .object(dictionary.mapValues(convert)) }
        if let array = value as? [Any] { return .array(array.map(convert)) }
        if let value = value as? String { return .string(value) }
        if let value = value as? Bool { return .boolean(value) }
        if let value = value as? NSNumber { return value.doubleValue.rounded() == value.doubleValue ? .integer(value.intValue) : .double(value.doubleValue) }
        return .null
    }
}
