// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum XcodeError: Error, Equatable, LocalizedError, Sendable {
    case invalidProjectPath
    case buildDisabled
    case commandFailed(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidProjectPath:
            return "Path must point to an existing .xcodeproj or .xcworkspace."
        case .buildDisabled:
            return "Xcode build is disabled. Set APPLE_DEBUG_ALLOW_XCODE_BUILD=1 for an authorized local build."
        case .commandFailed(let message):
            return "xcodebuild command failed: \(message)"
        case .invalidResponse:
            return "xcodebuild returned an invalid JSON project description."
        }
    }
}

public struct XcodeDiscoveryResult: Codable, Equatable, Sendable {
    public let path: String
    public let kind: String
    public let description: DAPValue

    public init(path: String, kind: String, description: DAPValue) {
        self.path = path
        self.kind = kind
        self.description = description
    }
}

public struct XcodeBuildResult: Codable, Equatable, Sendable {
    public let projectPath: String
    public let scheme: String
    public let configuration: String
    public let destination: String
    public let output: String

    public init(
        projectPath: String,
        scheme: String,
        configuration: String,
        destination: String,
        output: String
    ) {
        self.projectPath = projectPath
        self.scheme = scheme
        self.configuration = configuration
        self.destination = destination
        self.output = output
    }
}

public enum XcodeService {
    public static func discover(path: String) throws -> XcodeDiscoveryResult {
        let kind = try validateProject(path: path)
        let result = try run(arguments: [kind, path, "-list", "-json"])
        guard let data = result.stdout.data(using: .utf8),
              let description = try? JSONDecoder().decode(DAPValue.self, from: data) else {
            throw XcodeError.invalidResponse
        }
        return XcodeDiscoveryResult(path: path, kind: kind, description: description)
    }

    public static func build(
        path: String,
        scheme: String,
        configuration: String,
        destination: String
    ) throws -> XcodeBuildResult {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_XCODE_BUILD"] == "1" else {
            throw XcodeError.buildDisabled
        }
        let kind = try validateProject(path: path)
        let result = try run(arguments: [
            kind, path,
            "-scheme", scheme,
            "-configuration", configuration,
            "-destination", destination,
            "build"
        ])
        return XcodeBuildResult(
            projectPath: path,
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            output: result.stdout
        )
    }

    private static func validateProject(path: String) throws -> String {
        guard FileManager.default.fileExists(atPath: path) else {
            throw XcodeError.invalidProjectPath
        }
        if path.hasSuffix(".xcworkspace") {
            return "-workspace"
        }
        if path.hasSuffix(".xcodeproj") {
            return "-project"
        }
        throw XcodeError.invalidProjectPath
    }

    private struct CommandResult {
        let stdout: String
        let stderr: String
    }

    private static func run(arguments: [String]) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = arguments
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw XcodeError.commandFailed(error.localizedDescription)
        }

        let stdout = String(
            data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        let stderr = String(
            data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        guard process.terminationStatus == 0 else {
            throw XcodeError.commandFailed(
                stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? stdout : stderr
            )
        }
        return CommandResult(stdout: stdout, stderr: stderr)
    }
}
