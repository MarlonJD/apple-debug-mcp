// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum SimulatorEnvironmentError: Error, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case mutationDisabled
    case unknownSimulator(String)
    case commandFailed(String)
    case outputTooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidRequest: return "Simulator environment request is invalid or exceeds its bounded limits."
        case .mutationDisabled: return "Simulator environment mutation requires APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1."
        case .unknownSimulator(let udid): return "Simulator is not in the available inventory: \(udid)"
        case .commandFailed(let message): return "Simulator environment command failed: \(message)"
        case .outputTooLarge: return "Simulator environment output exceeds the configured limit."
        }
    }
}

public struct SimulatorEnvironmentResult: Codable, Equatable, Sendable {
    public let udid: String
    public let operation: String
    public let output: String

    public init(udid: String, operation: String, output: String) {
        self.udid = udid
        self.operation = operation
        self.output = output
    }
}

public enum AppleSimulatorEnvironmentService {
    private static let maximumOutput = 2 * 1024 * 1024
    private static let privacyServices = [
        "all", "calendar", "contacts-limited", "contacts", "location", "location-always",
        "photos-add", "photos", "media-library", "microphone", "motion", "reminders", "siri"
    ]
    private static let dataNetworks = ["hide", "wifi", "3g", "4g", "lte", "lte-a", "lte+", "5g", "5g+", "5g-uwb", "5g-uc"]
    private static let uiOptions = ["appearance", "increase_contrast", "content_size"]

    public static func perform(
        udid: String,
        operation: String,
        bundleID: String? = nil,
        service: String? = nil,
        value: String? = nil,
        payload: DAPValue? = nil,
        variable: String? = nil,
        mediaPaths: [String] = [],
        statusOverrides: [String: String] = [:]
    ) throws -> SimulatorEnvironmentResult {
        guard !operation.isEmpty, operation.utf8.count <= 64, !operation.contains("\0"),
              try SimulatorService.list().contains(where: { $0.udid == udid }) else {
            throw SimulatorEnvironmentError.unknownSimulator(udid)
        }
        let mutatingOperations = ["status_bar_override", "status_bar_clear", "ui_set", "privacy", "push", "pasteboard_set", "keychain_reset", "add_media"]
        if mutatingOperations.contains(operation) {
            guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION"] == "1" else {
                throw SimulatorEnvironmentError.mutationDisabled
            }
        }
        var arguments = ["simctl"]
        var input: Data?
        switch operation {
        case "status_bar_list":
            arguments += ["status_bar", udid, "list"]
        case "status_bar_clear":
            arguments += ["status_bar", udid, "clear"]
        case "status_bar_override":
            arguments += ["status_bar", udid, "override"]
            try appendStatusArguments(&arguments, overrides: statusOverrides)
        case "ui_get":
            guard let option = value, uiOptions.contains(option) else { throw SimulatorEnvironmentError.invalidRequest }
            arguments += ["ui", udid, option]
        case "ui_set":
            guard let option = service, uiOptions.contains(option), let setting = value else { throw SimulatorEnvironmentError.invalidRequest }
            try validateUISetting(option: option, value: setting)
            arguments += ["ui", udid, option, setting]
        case "privacy":
            guard let action = value, ["grant", "revoke", "reset"].contains(action),
                  let service, privacyServices.contains(service) else { throw SimulatorEnvironmentError.invalidRequest }
            arguments += ["privacy", udid, action, service]
            if action != "reset" || bundleID != nil {
                guard let bundleID, !bundleID.isEmpty, bundleID.utf8.count <= 256, !bundleID.contains("\0") else {
                    if action != "reset" { throw SimulatorEnvironmentError.invalidRequest }
                    return try execute(udid: udid, operation: operation, arguments: arguments)
                }
                arguments.append(bundleID)
            }
        case "push":
            guard let bundleID, !bundleID.isEmpty, bundleID.utf8.count <= 256, let payload,
                  case .object = payload else { throw SimulatorEnvironmentError.invalidRequest }
            let data = try JSONEncoder().encode(payload)
            guard data.count <= 4_096 else { throw SimulatorEnvironmentError.invalidRequest }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("apple-debug-mcp-push-\(UUID().uuidString).json")
            try data.write(to: url, options: .atomic)
            defer { try? FileManager.default.removeItem(at: url) }
            arguments += ["push", udid, bundleID, url.path]
        case "pasteboard_get":
            arguments += ["pbpaste", udid]
        case "pasteboard_set":
            guard let value, !value.contains("\0"), value.utf8.count <= 64 * 1024 else { throw SimulatorEnvironmentError.invalidRequest }
            arguments += ["pbcopy", udid]
            input = Data(value.utf8)
        case "keychain_reset":
            arguments += ["keychain", udid, "reset"]
        case "getenv":
            guard let variable, !variable.isEmpty, variable.utf8.count <= 256, !variable.contains("\0") else { throw SimulatorEnvironmentError.invalidRequest }
            arguments += ["getenv", udid, variable]
        case "list_apps":
            arguments += ["listapps", udid]
        case "add_media":
            guard !mediaPaths.isEmpty, mediaPaths.count <= 10,
                  mediaPaths.allSatisfy(validMediaPath) else { throw SimulatorEnvironmentError.invalidRequest }
            arguments += ["addmedia", udid] + mediaPaths
        default:
            throw SimulatorEnvironmentError.invalidRequest
        }
        return try execute(udid: udid, operation: operation, arguments: arguments, input: input)
    }

    private static func execute(udid: String, operation: String, arguments: [String], input: Data? = nil) throws -> SimulatorEnvironmentResult {
        let result: AppleProcessResult
        do {
            if let input { result = try runWithInput(arguments: arguments, input: input) }
            else {
                result = try AppleProcessRunner.run(executable: "/usr/bin/xcrun", arguments: arguments, maximumOutputSize: maximumOutput)
            }
        } catch AppleProcessRunnerError.outputTooLarge { throw SimulatorEnvironmentError.outputTooLarge }
        catch AppleProcessRunnerError.launchFailed(let message) { throw SimulatorEnvironmentError.commandFailed(message) }
        catch { throw SimulatorEnvironmentError.commandFailed(error.localizedDescription) }
        let stdout = String(decoding: result.stdout, as: UTF8.self)
        let stderr = String(decoding: result.stderr, as: UTF8.self)
        guard result.terminationStatus == 0 else {
            throw SimulatorEnvironmentError.commandFailed([stderr, stdout].filter { !$0.isEmpty }.joined(separator: "\n"))
        }
        return SimulatorEnvironmentResult(udid: udid, operation: operation, output: stdout)
    }

    private static func runWithInput(arguments: [String], input: Data) throws -> AppleProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("apple-debug-mcp-sim-env-\(UUID().uuidString).out")
        let errorURL = FileManager.default.temporaryDirectory.appendingPathComponent("apple-debug-mcp-sim-env-\(UUID().uuidString).err")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: outputURL); try? FileManager.default.removeItem(at: errorURL) }
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        process.standardOutput = outputHandle
        process.standardError = errorHandle
        try process.run()
        try inputPipe.fileHandleForWriting.write(contentsOf: input)
        try inputPipe.fileHandleForWriting.close()
        process.waitUntilExit()
        try outputHandle.close(); try errorHandle.close()
        let stdout = try Data(contentsOf: outputURL)
        let stderr = try Data(contentsOf: errorURL)
        guard stdout.count <= maximumOutput, stderr.count <= maximumOutput else { throw AppleProcessRunnerError.outputTooLarge }
        return AppleProcessResult(stdout: stdout, stderr: stderr, terminationStatus: process.terminationStatus)
    }

    private static func appendStatusArguments(_ arguments: inout [String], overrides: [String: String]) throws {
        let allowed = ["time", "dataNetwork", "wifiMode", "wifiBars", "cellularMode", "cellularBars", "operatorName", "batteryState", "batteryLevel"]
        guard !overrides.isEmpty, overrides.keys.allSatisfy(allowed.contains) else { throw SimulatorEnvironmentError.invalidRequest }
        for key in allowed where overrides[key] != nil {
            let value = overrides[key]!
            switch key {
            case "dataNetwork": guard dataNetworks.contains(value) else { throw SimulatorEnvironmentError.invalidRequest }
            case "wifiMode": guard ["searching", "failed", "active"].contains(value) else { throw SimulatorEnvironmentError.invalidRequest }
            case "wifiBars": guard let number = Int(value), (0...3).contains(number) else { throw SimulatorEnvironmentError.invalidRequest }
            case "cellularMode": guard ["notSupported", "searching", "failed", "active"].contains(value) else { throw SimulatorEnvironmentError.invalidRequest }
            case "cellularBars": guard let number = Int(value), (0...4).contains(number) else { throw SimulatorEnvironmentError.invalidRequest }
            case "batteryState": guard ["charging", "charged", "discharging"].contains(value) else { throw SimulatorEnvironmentError.invalidRequest }
            case "batteryLevel": guard let number = Int(value), (0...100).contains(number) else { throw SimulatorEnvironmentError.invalidRequest }
            default: guard !value.isEmpty, value.utf8.count <= 256, !value.contains("\0") else { throw SimulatorEnvironmentError.invalidRequest }
            }
            arguments += ["--\(key)", value]
        }
    }

    private static func validateUISetting(option: String, value: String) throws {
        switch option {
        case "appearance": guard ["light", "dark"].contains(value) else { throw SimulatorEnvironmentError.invalidRequest }
        case "increase_contrast": guard ["enabled", "disabled"].contains(value) else { throw SimulatorEnvironmentError.invalidRequest }
        case "content_size": guard ["increment", "decrement", "extra-small", "small", "medium", "large", "extra-large", "extra-extra-large", "extra-extra-extra-large", "accessibility-medium", "accessibility-large", "accessibility-extra-large", "accessibility-extra-extra-large", "accessibility-extra-extra-extra-large"].contains(value) else { throw SimulatorEnvironmentError.invalidRequest }
        default: throw SimulatorEnvironmentError.invalidRequest
        }
    }

    private static func validMediaPath(_ path: String) -> Bool {
        !path.isEmpty && path.utf8.count <= 4_096 && !path.contains("\0") && URL(fileURLWithPath: path).path.hasPrefix("/") && FileManager.default.fileExists(atPath: path)
    }
}
