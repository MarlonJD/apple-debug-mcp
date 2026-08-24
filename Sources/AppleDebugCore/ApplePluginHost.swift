// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct ApplePluginHostPlan: Codable, Equatable, Sendable {
    public let executablePath: String
    public let manifest: AppleDebugPluginManifest?
    public let signingAudit: AppleSigningAudit?
    public let sandboxRequired: Bool
    public let executionSupported: Bool
    public let reason: String

    public init(executablePath: String, manifest: AppleDebugPluginManifest?, signingAudit: AppleSigningAudit?, sandboxRequired: Bool, executionSupported: Bool, reason: String) {
        self.executablePath = executablePath
        self.manifest = manifest
        self.signingAudit = signingAudit
        self.sandboxRequired = sandboxRequired
        self.executionSupported = executionSupported
        self.reason = reason
    }
}

public enum ApplePluginHostError: Error, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case executableNotFound
    case unsignedExecutable
    case teamIdentifierMismatch

    public var errorDescription: String? {
        switch self {
        case .invalidRequest: return "Plugin host request is invalid or exceeds its bounded limits."
        case .executableNotFound: return "The plugin host executable was not found."
        case .unsignedExecutable: return "Plugin host executable must pass Apple code-signature verification."
        case .teamIdentifierMismatch: return "Plugin host team identifier does not match the requested signer."
        }
    }
}

public enum ApplePluginHostService {
    public static func plan(
        executablePath: String,
        manifestPath: String? = nil,
        requiredTeamIdentifier: String? = nil
    ) throws -> ApplePluginHostPlan {
        guard !executablePath.isEmpty, executablePath.utf8.count <= 4_096, !executablePath.contains("\0"), URL(fileURLWithPath: executablePath).path.hasPrefix("/") else {
            throw ApplePluginHostError.invalidRequest
        }
        guard FileManager.default.fileExists(atPath: executablePath) else { throw ApplePluginHostError.executableNotFound }
        let audit = try AppleSigningAuditService.inspect(path: executablePath)
        guard audit.verificationSucceeded else { throw ApplePluginHostError.unsignedExecutable }
        if let requiredTeamIdentifier, audit.teamIdentifier != requiredTeamIdentifier { throw ApplePluginHostError.teamIdentifierMismatch }
        var manifest: AppleDebugPluginManifest?
        if let manifestPath {
            guard manifestPath.utf8.count <= 4_096, !manifestPath.contains("\0"), FileManager.default.fileExists(atPath: manifestPath) else { throw ApplePluginHostError.invalidRequest }
            manifest = try JSONDecoder().decode(AppleDebugPluginManifest.self, from: Data(contentsOf: URL(fileURLWithPath: manifestPath)))
        }
        return ApplePluginHostPlan(
            executablePath: executablePath,
            manifest: manifest,
            signingAudit: audit,
            sandboxRequired: true,
            executionSupported: false,
            reason: "This release only validates the signed executable and returns a reviewable host plan. A future host must be a separately signed, sandboxed process with an explicit user grant; MCP does not execute arbitrary plugin code."
        )
    }
}
