// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum XcodeError: Error, Equatable, LocalizedError, Sendable {
    case invalidProjectPath
    case invalidBuildRequest
    case buildDisabled
    case testDisabled
    case commandFailed(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidProjectPath:
            return "Path must point to an existing .xcodeproj or .xcworkspace."
        case .invalidBuildRequest:
            return "Xcode build scheme, configuration, destination, or derived-data path is invalid."
        case .buildDisabled:
            return "Xcode build is disabled. Set APPLE_DEBUG_ALLOW_XCODE_BUILD=1 for an authorized local build."
        case .testDisabled:
            return "Xcode test execution is disabled. Set APPLE_DEBUG_ALLOW_XCODE_BUILD=1 for an authorized local test run."
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

public struct XcodeBuildArtifact: Codable, Equatable, Sendable {
    public let kind: String
    public let path: String
    public let exists: Bool

    public init(kind: String, path: String, exists: Bool) {
        self.kind = kind
        self.path = path
        self.exists = exists
    }
}

public struct XcodeBuildResult: Codable, Equatable, Sendable {
    public let projectPath: String
    public let scheme: String
    public let configuration: String
    public let destination: String
    public let derivedDataPath: String?
    public let artifacts: [XcodeBuildArtifact]
    public let output: String

    public init(
        projectPath: String,
        scheme: String,
        configuration: String,
        destination: String,
        derivedDataPath: String?,
        artifacts: [XcodeBuildArtifact],
        output: String
    ) {
        self.projectPath = projectPath
        self.scheme = scheme
        self.configuration = configuration
        self.destination = destination
        self.derivedDataPath = derivedDataPath
        self.artifacts = artifacts
        self.output = output
    }
}

public struct XcodeTestResult: Codable, Equatable, Sendable {
    public let projectPath: String
    public let scheme: String
    public let configuration: String
    public let destination: String
    public let resultBundlePath: String
    public let summary: DAPValue?
    public let output: String

    public init(
        projectPath: String,
        scheme: String,
        configuration: String,
        destination: String,
        resultBundlePath: String,
        summary: DAPValue?,
        output: String
    ) {
        self.projectPath = projectPath
        self.scheme = scheme
        self.configuration = configuration
        self.destination = destination
        self.resultBundlePath = resultBundlePath
        self.summary = summary
        self.output = output
    }
}

public enum XcodeService {
    private static let maximumCommandOutput = 16 * 1024 * 1024

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
        destination: String,
        derivedDataPath: String? = nil
    ) throws -> XcodeBuildResult {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_XCODE_BUILD"] == "1" else {
            throw XcodeError.buildDisabled
        }
        try validateBuildRequest(
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            derivedDataPath: derivedDataPath
        )
        let kind = try validateProject(path: path)
        var arguments = [
            kind, path,
            "-scheme", scheme,
            "-configuration", configuration,
            "-destination", destination,
        ]
        if let derivedDataPath {
            arguments += ["-derivedDataPath", derivedDataPath]
        }
        arguments.append("build")
        let result = try run(arguments: arguments)
        let settings = try showBuildSettings(
            kind: kind,
            path: path,
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            derivedDataPath: derivedDataPath
        )
        return XcodeBuildResult(
            projectPath: path,
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            derivedDataPath: derivedDataPath ?? settings.derivedDataPath,
            artifacts: settings.artifacts,
            output: result.stdout
        )
    }

    public static func test(
        path: String,
        scheme: String,
        configuration: String,
        destination: String,
        derivedDataPath: String? = nil,
        resultBundlePath: String? = nil,
        codeSigningAllowed: Bool = true
    ) throws -> XcodeTestResult {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_XCODE_BUILD"] == "1" else {
            throw XcodeError.testDisabled
        }
        try validateBuildRequest(
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            derivedDataPath: derivedDataPath
        )
        let kind = try validateProject(path: path)
        let resultURL = resultBundlePath.map(URL.init(fileURLWithPath:))
            ?? FileManager.default.temporaryDirectory
                .appendingPathComponent("apple-debug-mcp-(UUID().uuidString).xcresult")
        guard resultURL.path.hasPrefix("/"), !FileManager.default.fileExists(atPath: resultURL.path) else {
            throw XcodeError.invalidBuildRequest
        }
        var arguments = [
            kind, path,
            "-scheme", scheme,
            "-configuration", configuration,
            "-destination", destination,
            "-resultBundlePath", resultURL.path
        ]
        if let derivedDataPath {
            arguments += ["-derivedDataPath", derivedDataPath]
        }
        if !codeSigningAllowed {
            arguments.append("CODE_SIGNING_ALLOWED=NO")
        }
        arguments.append("test")
        let result = try run(arguments: arguments)
        let summary = try? testSummary(resultBundlePath: resultURL.path)
        return XcodeTestResult(
            projectPath: path,
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            resultBundlePath: resultURL.path,
            summary: summary,
            output: result.stdout
        )
    }

    private static func validateBuildRequest(
        scheme: String,
        configuration: String,
        destination: String,
        derivedDataPath: String?
    ) throws {
        guard !scheme.isEmpty, scheme.utf8.count <= 256,
              !configuration.isEmpty, configuration.utf8.count <= 256,
              !destination.isEmpty, destination.utf8.count <= 1_024,
              !scheme.contains("\0"), !configuration.contains("\0"),
              !destination.contains("\0") else {
            throw XcodeError.invalidBuildRequest
        }
        if let derivedDataPath {
            guard !derivedDataPath.isEmpty, derivedDataPath.utf8.count <= 4_096,
                  !derivedDataPath.contains("\0"),
                  URL(fileURLWithPath: derivedDataPath).path.hasPrefix("/") else {
                throw XcodeError.invalidBuildRequest
            }
        }
    }

    private static func testSummary(resultBundlePath: String) throws -> DAPValue {
        let result = try AppleProcessRunner.run(
            executable: "/usr/bin/xcrun",
            arguments: [
                "xcresulttool", "get", "test-results", "summary",
                "--path", resultBundlePath, "--compact"
            ],
            maximumOutputSize: 2 * 1024 * 1024
        )
        guard result.terminationStatus == 0 else {
            throw XcodeError.invalidResponse
        }
        return try JSONDecoder().decode(DAPValue.self, from: result.stdout)
    }

    private struct BuildSettingsResult {
        let derivedDataPath: String?
        let artifacts: [XcodeBuildArtifact]
    }

    private static func showBuildSettings(
        kind: String,
        path: String,
        scheme: String,
        configuration: String,
        destination: String,
        derivedDataPath: String?
    ) throws -> BuildSettingsResult {
        var arguments = [
            kind, path,
            "-scheme", scheme,
            "-configuration", configuration,
            "-destination", destination
        ]
        if let derivedDataPath {
            arguments += ["-derivedDataPath", derivedDataPath]
        }
        arguments += ["-showBuildSettings", "-json"]
        let result = try run(arguments: arguments)
        guard let data = result.stdout.data(using: .utf8),
              let values = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw XcodeError.invalidResponse
        }

        var artifacts: [XcodeBuildArtifact] = []
        var inferredDerivedDataPath: String?
        for value in values {
            guard let settings = value["buildSettings"] as? [String: Any] else { continue }
            let buildProducts = settings["BUILT_PRODUCTS_DIR"] as? String
            let productName = settings["FULL_PRODUCT_NAME"] as? String
            if let buildProducts, let productName {
                appendArtifact(
                    kind: productName.hasSuffix(".app") ? "app" : "product",
                    path: URL(fileURLWithPath: buildProducts).appendingPathComponent(productName).path,
                    to: &artifacts
                )
            }
            if let dsymDirectory = settings["DWARF_DSYM_FOLDER_PATH"] as? String,
               let dsymName = settings["DWARF_DSYM_FILE_NAME"] as? String {
                appendArtifact(
                    kind: "dSYM",
                    path: URL(fileURLWithPath: dsymDirectory).appendingPathComponent(dsymName).path,
                    to: &artifacts
                )
            }
            if inferredDerivedDataPath == nil,
               let buildDirectory = settings["BUILD_DIR"] as? String {
                inferredDerivedDataPath = URL(fileURLWithPath: buildDirectory)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .path
            }
        }
        return BuildSettingsResult(
            derivedDataPath: inferredDerivedDataPath,
            artifacts: artifacts
        )
    }

    private static func appendArtifact(
        kind: String,
        path: String,
        to artifacts: inout [XcodeBuildArtifact]
    ) {
        guard !artifacts.contains(where: { $0.path == path }) else { return }
        artifacts.append(
            XcodeBuildArtifact(
                kind: kind,
                path: path,
                exists: FileManager.default.fileExists(atPath: path)
            )
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
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-xcode-\(UUID().uuidString).stdout")
        let errorURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-xcode-\(UUID().uuidString).stderr")
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
            throw XcodeError.commandFailed(error.localizedDescription)
        }

        let stdoutData = try Data(contentsOf: outputURL)
        let stderrData = try Data(contentsOf: errorURL)
        guard stdoutData.count <= maximumCommandOutput,
              stderrData.count <= maximumCommandOutput else {
            throw XcodeError.commandFailed("xcodebuild output exceeds the 16 MB analysis limit.")
        }
        let stdout = String(decoding: stdoutData, as: UTF8.self)
        let stderr = String(decoding: stderrData, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw XcodeError.commandFailed(
                stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? stdout : stderr
            )
        }
        return CommandResult(stdout: stdout, stderr: stderr)
    }
}
