// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum SimulatorUIError: Error, Equatable, LocalizedError, Sendable {
    case mutationDisabled
    case invalidProject
    case invalidRequest
    case invalidAction
    case unknownSimulator(String)
    case commandFailed(String)
    case attachmentNotFound
    case invalidSnapshot
    case outputTooLarge

    public var errorDescription: String? {
        switch self {
        case .mutationDisabled:
            return "Simulator UI inspection is disabled. Set APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1 for an authorized local workflow."
        case .invalidProject:
            return "UI inspection requires an existing .xcodeproj or .xcworkspace with a UI-test-enabled scheme."
        case .invalidRequest:
            return "Simulator UI inspection request is invalid."
        case .invalidAction:
            return "Simulator UI action is unsupported or missing its required fields."
        case .unknownSimulator(let udid):
            return "Simulator is not in the available inventory: \(udid)"
        case .commandFailed(let message):
            return "Simulator UI test command failed: \(message)"
        case .attachmentNotFound:
            return "The UI test completed without producing an accessibility-tree attachment."
        case .invalidSnapshot:
            return "The UI test attachment is not a valid Apple Debug MCP snapshot."
        case .outputTooLarge:
            return "Simulator UI test output exceeds the configured response limit."
        }
    }
}

public struct SimulatorUIElement: Codable, Equatable, Sendable {
    public let type: UInt
    public let identifier: String
    public let label: String
    public let value: String?
    public let exists: Bool
    public let hittable: Bool
    public let frame: [String: Double]

    public init(
        type: UInt,
        identifier: String,
        label: String,
        value: String?,
        exists: Bool,
        hittable: Bool,
        frame: [String: Double]
    ) {
        self.type = type
        self.identifier = identifier
        self.label = label
        self.value = value
        self.exists = exists
        self.hittable = hittable
        self.frame = frame
    }
}

public struct SimulatorUISnapshot: Codable, Equatable, Sendable {
    public let udid: String
    public let bundleID: String
    public let projectPath: String
    public let scheme: String
    public let debugDescription: String
    public let elements: [SimulatorUIElement]

    public init(
        udid: String,
        bundleID: String,
        projectPath: String,
        scheme: String,
        debugDescription: String,
        elements: [SimulatorUIElement]
    ) {
        self.udid = udid
        self.bundleID = bundleID
        self.projectPath = projectPath
        self.scheme = scheme
        self.debugDescription = debugDescription
        self.elements = elements
    }
}

public struct SimulatorUIActionRequest: Codable, Equatable, Sendable {
    public let action: String
    public let identifier: String?
    public let text: String?
    public let direction: String?

    public init(action: String, identifier: String? = nil, text: String? = nil, direction: String? = nil) {
        self.action = action
        self.identifier = identifier
        self.text = text
        self.direction = direction
    }
}

public struct SimulatorUIActionResult: Codable, Equatable, Sendable {
    public let action: String
    public let snapshot: SimulatorUISnapshot

    public init(action: String, snapshot: SimulatorUISnapshot) {
        self.action = action
        self.snapshot = snapshot
    }
}

public enum SimulatorUIService {
    private static let maximumCommandOutput = 8 * 1024 * 1024
    private static let maximumSnapshotSize = 4 * 1024 * 1024

    public static func snapshot(
        udid: String,
        bundleID: String,
        projectPath: String,
        scheme: String,
        configuration: String = "Debug"
    ) throws -> SimulatorUISnapshot {
        try runProbe(
            udid: udid,
            bundleID: bundleID,
            projectPath: projectPath,
            scheme: scheme,
            configuration: configuration,
            action: nil
        )
    }

    public static func performAction(
        udid: String,
        bundleID: String,
        projectPath: String,
        scheme: String,
        configuration: String = "Debug",
        action: SimulatorUIActionRequest
    ) throws -> SimulatorUIActionResult {
        try validate(action: action)
        let snapshot = try runProbe(
            udid: udid,
            bundleID: bundleID,
            projectPath: projectPath,
            scheme: scheme,
            configuration: configuration,
            action: action
        )
        return SimulatorUIActionResult(action: action.action, snapshot: snapshot)
    }

    private static func runProbe(
        udid: String,
        bundleID: String,
        projectPath: String,
        scheme: String,
        configuration: String,
        action: SimulatorUIActionRequest?
    ) throws -> SimulatorUISnapshot {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION"] == "1" else {
            throw SimulatorUIError.mutationDisabled
        }
        guard !bundleID.isEmpty, !scheme.isEmpty,
              bundleID.utf8.count <= 256, scheme.utf8.count <= 256 else {
            throw SimulatorUIError.invalidRequest
        }
        let projectURL = URL(fileURLWithPath: projectPath)
        guard FileManager.default.fileExists(atPath: projectURL.path),
              projectURL.pathExtension == "xcodeproj" || projectURL.pathExtension == "xcworkspace" else {
            throw SimulatorUIError.invalidProject
        }
        guard try SimulatorService.list().contains(where: { $0.udid == udid }) else {
            throw SimulatorUIError.unknownSimulator(udid)
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-ui-\(UUID().uuidString)", isDirectory: true)
        let derivedData = root.appendingPathComponent("DerivedData", isDirectory: true)
        let resultBundle = root.appendingPathComponent("UI.xcresult", isDirectory: true)
        let attachments = root.appendingPathComponent("attachments", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let projectFlag = projectURL.pathExtension == "xcodeproj" ? "-project" : "-workspace"
        var xcodebuildArguments = [
            projectFlag, projectURL.path,
            "-scheme", scheme,
            "-configuration", configuration,
            "-destination", "platform=iOS Simulator,id=\(udid)",
            "-derivedDataPath", derivedData.path,
            "-resultBundlePath", resultBundle.path,
            "CODE_SIGNING_ALLOWED=NO"
        ]
        if let action {
            let actionData = try JSONEncoder().encode(action)
            xcodebuildArguments.append(
                "APPLE_DEBUG_UI_ACTION_BASE64=\(actionData.base64EncodedString())"
            )
        }
        xcodebuildArguments.append("test")
        let buildResult = try run(
            executable: "/usr/bin/xcodebuild",
            arguments: xcodebuildArguments
        )
        _ = buildResult

        try FileManager.default.createDirectory(at: attachments, withIntermediateDirectories: true)
        _ = try run(
            executable: "/usr/bin/xcrun",
            arguments: [
                "xcresulttool", "export", "attachments",
                "--path", resultBundle.path,
                "--output-path", attachments.path
            ]
        )
        let manifestURL = attachments.appendingPathComponent("manifest.json")
        guard let manifestData = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONSerialization.jsonObject(with: manifestData) as? [[String: Any]] else {
            throw SimulatorUIError.attachmentNotFound
        }

        for test in manifest {
            guard let records = test["attachments"] as? [[String: Any]] else { continue }
            for record in records {
                guard let exportedFileName = record["exportedFileName"] as? String,
                      let suggestedName = record["suggestedHumanReadableName"] as? String,
                      suggestedName.hasPrefix("apple-debug-mcp-ui-tree") else {
                    continue
                }
                let attachmentURL = attachments.appendingPathComponent(exportedFileName)
                guard let data = try? Data(contentsOf: attachmentURL), data.count <= maximumSnapshotSize else {
                    throw SimulatorUIError.outputTooLarge
                }
                do {
                    let payload = try JSONDecoder().decode(AccessibilityPayload.self, from: data)
                    return SimulatorUISnapshot(
                        udid: udid,
                        bundleID: bundleID,
                        projectPath: projectURL.path,
                        scheme: scheme,
                        debugDescription: payload.debugDescription,
                        elements: payload.elements
                    )
                } catch {
                    throw SimulatorUIError.invalidSnapshot
                }
            }
        }
        throw SimulatorUIError.attachmentNotFound
    }

    private static func validate(action: SimulatorUIActionRequest) throws {
        guard ["tap", "typeText", "swipe", "wait"].contains(action.action) else {
            throw SimulatorUIError.invalidAction
        }
        if let identifier = action.identifier {
            guard !identifier.isEmpty, identifier.utf8.count <= 256, !identifier.contains("\0") else {
                throw SimulatorUIError.invalidAction
            }
        }
        switch action.action {
        case "tap", "wait":
            guard action.identifier != nil else { throw SimulatorUIError.invalidAction }
        case "typeText":
            guard action.identifier != nil,
                  let text = action.text,
                  !text.contains("\0"),
                  text.utf8.count <= 4096 else {
                throw SimulatorUIError.invalidAction
            }
        case "swipe":
            guard ["up", "down", "left", "right"].contains(action.direction ?? "up") else {
                throw SimulatorUIError.invalidAction
            }
        default:
            throw SimulatorUIError.invalidAction
        }
    }

    private struct AccessibilityPayload: Codable {
        let bundleID: String
        let debugDescription: String
        let elements: [SimulatorUIElement]
        let action: String?
    }

    private struct CommandResult {
        let stdout: String
        let stderr: String
    }

    private static func run(executable: String, arguments: [String]) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-ui-\(UUID().uuidString).stdout")
        let errorURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-ui-\(UUID().uuidString).stderr")
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
            throw SimulatorUIError.commandFailed(error.localizedDescription)
        }

        let stdoutData = try Data(contentsOf: outputURL)
        let stderrData = try Data(contentsOf: errorURL)
        guard stdoutData.count <= maximumCommandOutput,
              stderrData.count <= maximumCommandOutput else {
            throw SimulatorUIError.outputTooLarge
        }
        let stdout = String(decoding: stdoutData, as: UTF8.self)
        let stderr = String(decoding: stderrData, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw SimulatorUIError.commandFailed(
                stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? stdout : stderr
            )
        }
        return CommandResult(stdout: stdout, stderr: stderr)
    }
}
