// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Darwin

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

public struct ApplePluginHostExecutionResult: Codable, Equatable, Sendable {
    public let pluginID: String
    public let executablePath: String
    public let sandboxed: Bool
    public let exitCode: Int32
    public let timedOut: Bool
    public let stdout: String
    public let stderr: String
    public let notes: [String]

    public init(pluginID: String, executablePath: String, sandboxed: Bool, exitCode: Int32, timedOut: Bool, stdout: String, stderr: String, notes: [String]) {
        self.pluginID = pluginID
        self.executablePath = executablePath
        self.sandboxed = sandboxed
        self.exitCode = exitCode
        self.timedOut = timedOut
        self.stdout = stdout
        self.stderr = stderr
        self.notes = notes
    }
}

public enum ApplePluginHostError: Error, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case executableNotFound
    case unsignedExecutable
    case teamIdentifierMismatch
    case executionDisabled
    case sandboxUnavailable
    case timedOut
    case outputTooLarge
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidRequest: return "Plugin host request is invalid or exceeds its bounded limits."
        case .executableNotFound: return "The plugin host executable was not found."
        case .unsignedExecutable: return "Plugin host executable must pass Apple code-signature verification."
        case .teamIdentifierMismatch: return "Plugin host team identifier does not match the requested signer."
        case .executionDisabled: return "Plugin execution is disabled. Set APPLE_DEBUG_ALLOW_PLUGIN_EXECUTION=1 only for an authorized plugin test."
        case .sandboxUnavailable: return "The required macOS sandbox-exec boundary is unavailable."
        case .timedOut: return "The sandboxed plugin exceeded the bounded execution timeout."
        case .outputTooLarge: return "The sandboxed plugin exceeded the bounded stdout/stderr limit."
        case .executionFailed(let message): return "Sandboxed plugin execution failed: \(message)"
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
            executionSupported: true,
            reason: "The separate sandboxed host is available, but this plan operation remains non-executing. Use apple_plugin_host_execute with an explicit execution grant; MCP never loads arbitrary plugin code in-process."
        )
    }

    public static func execute(
        executablePath: String,
        manifestPath: String,
        input: String,
        requiredTeamIdentifier: String? = nil,
        timeoutSeconds: Double = 10.0
    ) throws -> ApplePluginHostExecutionResult {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_PLUGIN_EXECUTION"] == "1" else {
            throw ApplePluginHostError.executionDisabled
        }
        guard timeoutSeconds.isFinite, (0.1...30.0).contains(timeoutSeconds),
              input.utf8.count <= 256 * 1024,
              !input.contains("\0") else {
            throw ApplePluginHostError.invalidRequest
        }
        let manifest = try loadManifest(path: manifestPath)
        let audit = try AppleSigningAuditService.inspect(path: executablePath)
        guard audit.verificationSucceeded else { throw ApplePluginHostError.unsignedExecutable }
        if let requiredTeamIdentifier, audit.teamIdentifier != requiredTeamIdentifier {
            throw ApplePluginHostError.teamIdentifierMismatch
        }
        if let entrypoint = manifest.entrypoint,
           entrypoint != URL(fileURLWithPath: executablePath).lastPathComponent {
            throw ApplePluginHostError.invalidRequest
        }
        guard let sandboxExec = FileManager.default.fileExists(atPath: "/usr/bin/sandbox-exec") ? "/usr/bin/sandbox-exec" : nil else {
            throw ApplePluginHostError.sandboxUnavailable
        }
        let resolvedExecutable = URL(fileURLWithPath: executablePath).resolvingSymlinksInPath().path
        let profile = try sandboxProfile(for: resolvedExecutable)
        let result = try runSandboxed(
            sandboxExec: sandboxExec,
            profile: profile,
            executablePath: resolvedExecutable,
            input: input,
            timeoutSeconds: timeoutSeconds
        )
        return ApplePluginHostExecutionResult(
            pluginID: manifest.id,
            executablePath: resolvedExecutable,
            sandboxed: true,
            exitCode: result.exitCode,
            timedOut: result.timedOut,
            stdout: result.stdout,
            stderr: result.stderr,
            notes: [
                "Plugin ran in a separate deny-by-default macOS sandbox profile with network access denied.",
                "The MCP process did not load the plugin as a dylib or invoke plugin code in-process.",
                "Signature and optional team identity were verified before launch."
            ]
        )
    }

    private static let maximumOutputSize = 1 * 1024 * 1024

    private static func loadManifest(path: String) throws -> AppleDebugPluginManifest {
        guard !path.isEmpty, path.utf8.count <= 4_096, !path.contains("\0"),
              URL(fileURLWithPath: path).path.hasPrefix("/"),
              FileManager.default.fileExists(atPath: path) else {
            throw ApplePluginHostError.invalidRequest
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard data.count <= 64 * 1024 else { throw ApplePluginHostError.invalidRequest }
        do {
            let manifest = try JSONDecoder().decode(AppleDebugPluginManifest.self, from: data)
            guard !manifest.id.isEmpty, !manifest.name.isEmpty, !manifest.version.isEmpty else {
                throw ApplePluginHostError.invalidRequest
            }
            return manifest
        } catch let error as ApplePluginHostError {
            throw error
        } catch {
            throw ApplePluginHostError.invalidRequest
        }
    }

    private static func sandboxProfile(for executablePath: String) throws -> String {
        guard !executablePath.contains("\n"), !executablePath.contains("\r"), !executablePath.contains("\"") else {
            throw ApplePluginHostError.invalidRequest
        }
        let escaped = executablePath.replacingOccurrences(of: "\\", with: "\\\\")
        return """
        (version 1)
        (deny default)
        (allow process-fork)
        (allow process-exec (literal "\(escaped)"))
        (allow file-read-metadata)
        (allow file-read*)
        (deny file-read* (subpath "/Users") (subpath "/private/etc") (subpath "/private/var/db") (subpath "/System/Volumes/Data/Users"))
        (allow sysctl-read)
        (deny network*)
        """
    }

    private static func runSandboxed(
        sandboxExec: String,
        profile: String,
        executablePath: String,
        input: String,
        timeoutSeconds: Double
    ) throws -> (exitCode: Int32, timedOut: Bool, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sandboxExec)
        process.arguments = ["-p", profile, executablePath]
        let inputPipe = Pipe()
        let stdoutURL = FileManager.default.temporaryDirectory.appendingPathComponent("apple-debug-mcp-plugin-\(UUID().uuidString).stdout")
        let stderrURL = FileManager.default.temporaryDirectory.appendingPathComponent("apple-debug-mcp-plugin-\(UUID().uuidString).stderr")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        defer {
            try? FileManager.default.removeItem(at: stdoutURL)
            try? FileManager.default.removeItem(at: stderrURL)
        }
        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)
        process.standardInput = inputPipe
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle
        let termination = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in termination.signal() }
        do {
            try process.run()
        } catch {
            try? stdoutHandle.close()
            try? stderrHandle.close()
            throw ApplePluginHostError.executionFailed(error.localizedDescription)
        }
        inputPipe.fileHandleForWriting.write(Data(input.utf8))
        try? inputPipe.fileHandleForWriting.close()
        let deadline = DispatchTime.now() + timeoutSeconds
        var timedOut = false
        if termination.wait(timeout: deadline) == .timedOut {
            timedOut = true
            process.terminate()
            if termination.wait(timeout: .now() + 1.0) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = termination.wait(timeout: .now() + 1.0)
            }
        }
        try? stdoutHandle.close()
        try? stderrHandle.close()
        let stdout = try Data(contentsOf: stdoutURL)
        let stderr = try Data(contentsOf: stderrURL)
        guard stdout.count <= maximumOutputSize, stderr.count <= maximumOutputSize else {
            throw ApplePluginHostError.outputTooLarge
        }
        if timedOut { throw ApplePluginHostError.timedOut }
        return (
            process.terminationStatus,
            false,
            String(decoding: stdout, as: UTF8.self),
            String(decoding: stderr, as: UTF8.self)
        )
    }
}
