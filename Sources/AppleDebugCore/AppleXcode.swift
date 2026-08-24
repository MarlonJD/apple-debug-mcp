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

public struct XcodeSwiftTargetContext: Codable, Equatable, Sendable {
    public let projectPath: String
    public let scheme: String
    public let configuration: String
    public let destination: String
    public let targetName: String
    public let moduleName: String
    public let sourcePaths: [String]
    public let sdkRoot: String?
    public let targetTriple: String?
    public let settings: [String: String]
    public let notes: [String]

    public init(projectPath: String, scheme: String, configuration: String, destination: String, targetName: String, moduleName: String, sourcePaths: [String], sdkRoot: String?, targetTriple: String?, settings: [String: String], notes: [String]) {
        self.projectPath = projectPath
        self.scheme = scheme
        self.configuration = configuration
        self.destination = destination
        self.targetName = targetName
        self.moduleName = moduleName
        self.sourcePaths = sourcePaths
        self.sdkRoot = sdkRoot
        self.targetTriple = targetTriple
        self.settings = settings
        self.notes = notes
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

    public static func swiftTargetContext(
        path: String,
        scheme: String,
        configuration: String = "Debug",
        destination: String = "generic/platform=macOS"
    ) throws -> XcodeSwiftTargetContext {
        try validateBuildRequest(
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            derivedDataPath: nil
        )
        let kind = try validateProject(path: path)
        let result = try run(arguments: [
            kind, path,
            "-scheme", scheme,
            "-configuration", configuration,
            "-destination", destination,
            "-showBuildSettings", "-json"
        ])
        guard let data = result.stdout.data(using: .utf8),
              let values = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw XcodeError.invalidResponse
        }
        let settingsValue = values.compactMap { $0["buildSettings"] as? [String: Any] }
            .first { ($0["TARGET_NAME"] as? String) == scheme }
            ?? values.compactMap { $0["buildSettings"] as? [String: Any] }.first
        guard let settingsValue else { throw XcodeError.invalidResponse }
        let settings = settingsValue.reduce(into: [String: String]()) { result, entry in
            if let value = entry.value as? String, value.utf8.count <= 4_096 {
                result[entry.key] = value
            }
        }
        let targetName = settings["TARGET_NAME"] ?? scheme
        let moduleName = settings["PRODUCT_MODULE_NAME"] ?? settings["PRODUCT_NAME"] ?? targetName
        guard validModuleName(moduleName) else { throw XcodeError.invalidResponse }
        let projectDirectory = URL(fileURLWithPath: path).deletingLastPathComponent()
        let sourceDiscovery = discoverSwiftSources(
            projectPath: path,
            projectDirectory: projectDirectory,
            targetName: targetName
        )
        guard !sourceDiscovery.paths.isEmpty else {
            throw XcodeError.commandFailed("No bounded Swift source files were found for target \(targetName).")
        }
        let sdkRoot = settings["SDKROOT"].flatMap { value in
            let url = URL(fileURLWithPath: value)
            return FileManager.default.fileExists(atPath: url.path) ? url.path : nil
        }
        let targetTriple = swiftTargetTriple(settings: settings)
        return XcodeSwiftTargetContext(
            projectPath: path,
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            targetName: targetName,
            moduleName: moduleName,
            sourcePaths: sourceDiscovery.paths,
            sdkRoot: sdkRoot,
            targetTriple: targetTriple,
            settings: settings.filter { ["PRODUCT_MODULE_NAME", "PRODUCT_NAME", "SDK_NAME", "SDKROOT", "SWIFT_VERSION", "TARGET_NAME", "IPHONEOS_DEPLOYMENT_TARGET", "MACOSX_DEPLOYMENT_TARGET", "WATCHOS_DEPLOYMENT_TARGET", "TVOS_DEPLOYMENT_TARGET"].contains($0.key) },
            notes: sourceDiscovery.usedFallback
                ? ["Source files were discovered by bounded project-tree enumeration because the target's PBX source phase could not be resolved.", "xcodebuild showBuildSettings supplied the module, SDK, and target context; no build was performed."]
                : ["Source files were resolved from the selected target's PBX Sources build phase.", "xcodebuild showBuildSettings supplied the module, SDK, and target context; no build was performed."]
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

    private static func validModuleName(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 256 && value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    private static func swiftTargetTriple(settings: [String: String]) -> String? {
        guard let sdkName = settings["SDK_NAME"] else { return nil }
        let architecture = settings["CURRENT_ARCH"]
            .flatMap { $0 == "undefined_arch" ? nil : $0 }
            ?? settings["ARCHS"]?.split(separator: " ").first.map(String.init)
            ?? "arm64"
        if sdkName.hasPrefix("iphonesimulator") {
            let version = String(sdkName.dropFirst("iphonesimulator".count))
            return "\(architecture)-apple-ios\(version)-simulator"
        }
        if sdkName.hasPrefix("iphoneos") {
            let version = String(sdkName.dropFirst("iphoneos".count))
            return "\(architecture)-apple-ios\(version)"
        }
        if sdkName.hasPrefix("macosx") {
            let version = String(sdkName.dropFirst("macosx".count))
            return "\(architecture)-apple-macos\(version)"
        }
        if sdkName.hasPrefix("appletvsimulator") {
            let version = String(sdkName.dropFirst("appletvsimulator".count))
            return "\(architecture)-apple-tvos\(version)-simulator"
        }
        if sdkName.hasPrefix("appletvos") {
            let version = String(sdkName.dropFirst("appletvos".count))
            return "\(architecture)-apple-tvos\(version)"
        }
        if sdkName.hasPrefix("watchsimulator") {
            let version = String(sdkName.dropFirst("watchsimulator".count))
            return "\(architecture)-apple-watchos\(version)-simulator"
        }
        if sdkName.hasPrefix("watchos") {
            let version = String(sdkName.dropFirst("watchos".count))
            return "\(architecture)-apple-watchos\(version)"
        }
        return nil
    }

    private static func discoverSwiftSources(
        projectPath: String,
        projectDirectory: URL,
        targetName: String
    ) -> (paths: [String], usedFallback: Bool) {
        if projectPath.hasSuffix(".xcodeproj") {
            let pbxPath = URL(fileURLWithPath: projectPath).appendingPathComponent("project.pbxproj")
            if let text = try? String(contentsOf: pbxPath, encoding: .utf8),
               let paths = resolvePBXSources(text: text, projectDirectory: projectDirectory, targetName: targetName),
               !paths.isEmpty {
                return (paths, false)
            }
        }
        var paths: [String] = []
        guard let enumerator = FileManager.default.enumerator(
            at: projectDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return ([], true) }
        for case let url as URL in enumerator {
            if url.pathComponents.contains(where: { [".git", "DerivedData", "build", ".build", "Pods", "Carthage"].contains($0) }) {
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard url.pathExtension == "swift",
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            let lowerName = url.deletingPathExtension().lastPathComponent.localizedLowercase
            let lowerTarget = targetName.localizedLowercase
            if !lowerTarget.contains("test"),
               lowerName.contains("uitest") || lowerName.hasSuffix("tests") || lowerName.hasSuffix("test") {
                continue
            }
            paths.append(url.path)
            if paths.count >= 256 { break }
        }
        return (paths.sorted(), true)
    }

    private static func resolvePBXSources(
        text: String,
        projectDirectory: URL,
        targetName: String
    ) -> [String]? {
        guard let target = pbxBlock(in: text, marker: "/* \(targetName) */ = {") else { return nil }
        let sourcePhaseIDs = target
            .split(whereSeparator: \.isNewline)
            .filter { $0.contains("/* Sources */") }
            .compactMap { line -> String? in
                let token = line.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "(" || $0 == ")" || $0 == "," }).first.map(String.init)
                return token?.allSatisfy(\.isHexDigit) == true ? token : nil
            }
        guard !sourcePhaseIDs.isEmpty else { return nil }
        var paths: [String] = []
        for phaseID in sourcePhaseIDs {
            guard let phase = pbxBlock(in: text, marker: "\(phaseID) /* Sources */ = {") else { continue }
            for line in phase.split(whereSeparator: \.isNewline) where line.contains(" in Sources */") {
                guard let buildID = line.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "," }).first,
                      buildID.allSatisfy(\.isHexDigit),
                      let build = pbxBlock(in: text, marker: "\(buildID) /*") else { continue }
                guard let rawFileRef = value(after: "fileRef = ", in: build),
                      let fileRef = rawFileRef.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) else { continue }
                let commentName = line.split(separator: "/*", maxSplits: 1).dropFirst().first
                    .map(String.init)
                    .map { $0.replacingOccurrences(of: " in Sources */", with: "") }
                    .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \t,*/")) }
                let fileBlock = commentName.flatMap { name in
                    pbxBlock(in: text, marker: "\(fileRef) /* \(name) */ = {")
                }
                let pathValue = fileBlock.flatMap { value(after: "path = ", in: $0) }
                let relativePath = pathValue?.trimmingCharacters(in: CharacterSet(charactersIn: " \t;\"")) ?? commentName
                guard let relativePath, relativePath.hasSuffix(".swift") else { continue }
                let candidate = projectDirectory.appendingPathComponent(relativePath).standardizedFileURL.path
                guard FileManager.default.fileExists(atPath: candidate) else { continue }
                paths.append(candidate)
            }
        }
        return Array(Set(paths)).sorted()
    }

    private static func pbxBlock(in text: String, marker: String) -> String? {
        guard let markerRange = text.range(of: marker),
              let opening = text[markerRange.lowerBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var cursor = opening
        while cursor < text.endIndex {
            if text[cursor] == "{" { depth += 1 }
            if text[cursor] == "}" {
                depth -= 1
                if depth == 0 {
                    return String(text[opening...cursor])
                }
            }
            cursor = text.index(after: cursor)
        }
        return nil
    }

    private static func value(after prefix: String, in text: String) -> String? {
        guard let range = text.range(of: prefix),
              let end = text[range.upperBound...].firstIndex(of: ";") else { return nil }
        return String(text[range.upperBound..<end])
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
