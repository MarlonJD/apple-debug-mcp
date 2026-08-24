// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Darwin

public enum SimulatorError: Error, Equatable, LocalizedError, Sendable {
    case commandFailed(String)
    case mutationDisabled
    case invalidLaunchArguments
    case invalidURL
    case invalidLocation
    case invalidRecordingRequest
    case unknownDevice(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return "Simulator command failed: \(message)"
        case .mutationDisabled:
            return "Simulator mutation is disabled. Set APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1 for an authorized local workflow."
        case .invalidLaunchArguments:
            return "Simulator launch arguments are invalid or exceed the safety limit."
        case .invalidURL:
            return "Simulator URL must be a bounded URL with a scheme and no embedded control characters."
        case .invalidLocation:
            return "Simulator location coordinates are outside the valid latitude/longitude ranges."
        case .invalidRecordingRequest:
            return "Simulator video recording request is invalid, unsafe, or targets an existing file."
        case .unknownDevice(let identifier):
            return "Simulator is not in the available inventory: \(identifier)"
        case .invalidResponse:
            return "simctl returned an invalid device inventory."
        }
    }
}

public struct SimulatorDevice: Codable, Equatable, Sendable {
    public let udid: String
    public let name: String
    public let runtime: String
    public let state: String
    public let isAvailable: Bool

    public init(udid: String, name: String, runtime: String, state: String, isAvailable: Bool) {
        self.udid = udid
        self.name = name
        self.runtime = runtime
        self.state = state
        self.isAvailable = isAvailable
    }
}

public struct SimulatorActionResult: Codable, Equatable, Sendable {
    public let action: String
    public let udid: String
    public let output: String

    public init(action: String, udid: String, output: String) {
        self.action = action
        self.udid = udid
        self.output = output
    }
}

public struct SimulatorAppInfoResult: Codable, Equatable, Sendable {
    public let udid: String
    public let bundleID: String
    public let output: String

    public init(udid: String, bundleID: String, output: String) {
        self.udid = udid
        self.bundleID = bundleID
        self.output = output
    }
}

public struct SimulatorContainerResult: Codable, Equatable, Sendable {
    public let udid: String
    public let bundleID: String
    public let container: String
    public let path: String

    public init(udid: String, bundleID: String, container: String, path: String) {
        self.udid = udid
        self.bundleID = bundleID
        self.container = container
        self.path = path
    }
}

public struct SimulatorRecordingResult: Codable, Equatable, Sendable {
    public let udid: String
    public let path: String
    public let durationSeconds: Int
    public let codec: String

    public init(udid: String, path: String, durationSeconds: Int, codec: String) {
        self.udid = udid
        self.path = path
        self.durationSeconds = durationSeconds
        self.codec = codec
    }
}

public enum SimulatorService {
    public static func list() throws -> [SimulatorDevice] {
        let result = try run(arguments: ["simctl", "list", "devices", "available", "--json"])
        guard let root = try JSONSerialization.jsonObject(with: Data(result.stdout.utf8)) as? [String: Any],
              let runtimes = root["devices"] as? [String: [[String: Any]]] else {
            throw SimulatorError.invalidResponse
        }

        return runtimes.flatMap { runtime, devices in
            devices.compactMap { device in
                guard let udid = device["udid"] as? String,
                      let name = device["name"] as? String,
                      let state = device["state"] as? String else {
                    return nil
                }
                return SimulatorDevice(
                    udid: udid,
                    name: name,
                    runtime: runtime,
                    state: state,
                    isAvailable: device["isAvailable"] as? Bool ?? true
                )
            }
        }
        .sorted {
            ($0.runtime, $0.name, $0.udid) < ($1.runtime, $1.name, $1.udid)
        }
    }

    public static func boot(udid: String) throws -> SimulatorActionResult {
        try validateMutationTarget(udid: udid)
        let boot = try run(arguments: ["simctl", "boot", udid])
        let status = try run(arguments: ["simctl", "bootstatus", udid, "-b"])
        return SimulatorActionResult(
            action: "boot",
            udid: udid,
            output: [boot.stdout, status.stdout]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        )
    }

    public static func shutdown(udid: String) throws -> SimulatorActionResult {
        try mutate(action: "shutdown", udid: udid, arguments: ["simctl", "shutdown", udid])
    }

    public static func install(udid: String, appPath: String) throws -> SimulatorActionResult {
        try mutate(action: "install", udid: udid, arguments: ["simctl", "install", udid, appPath])
    }

    public static func launch(
        udid: String,
        bundleID: String,
        arguments: [String] = [],
        terminateRunning: Bool = false,
        waitForDebugger: Bool = false
    ) throws -> SimulatorActionResult {
        guard arguments.count <= 64,
              arguments.allSatisfy({ !$0.contains("\0") && $0.utf8.count <= 4096 }) else {
            throw SimulatorError.invalidLaunchArguments
        }
        var command = ["simctl", "launch"]
        if waitForDebugger {
            command.append("--wait-for-debugger")
        }
        if terminateRunning {
            command.append("--terminate-running-process")
        }
        command.append(udid)
        command.append(bundleID)
        command.append(contentsOf: arguments)
        return try mutate(action: "launch", udid: udid, arguments: command)
    }

    public static func terminate(udid: String, bundleID: String) throws -> SimulatorActionResult {
        try mutate(action: "terminate", udid: udid, arguments: ["simctl", "terminate", udid, bundleID])
    }

    public static func screenshot(udid: String, path: String? = nil) throws -> SimulatorActionResult {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION"] == "1" else {
            throw SimulatorError.mutationDisabled
        }
        guard try list().contains(where: { $0.udid == udid }) else {
            throw SimulatorError.unknownDevice(udid)
        }

        let destination = path ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-\(UUID().uuidString).png")
            .path
        let result = try run(arguments: ["simctl", "io", udid, "screenshot", destination])
        return SimulatorActionResult(action: "screenshot", udid: udid, output: result.stdout.isEmpty ? destination : result.stdout)
    }

    public static func openURL(udid: String, url: String) throws -> SimulatorActionResult {
        guard let parsed = URL(string: url), parsed.scheme != nil,
              !url.isEmpty, url.utf8.count <= 2_048, !url.contains("\0") else {
            throw SimulatorError.invalidURL
        }
        return try mutate(action: "openurl", udid: udid, arguments: ["simctl", "openurl", udid, url])
    }

    public static func setLocation(
        udid: String,
        latitude: Double,
        longitude: Double
    ) throws -> SimulatorActionResult {
        guard (-90.0...90.0).contains(latitude), (-180.0...180.0).contains(longitude),
              latitude.isFinite, longitude.isFinite else {
            throw SimulatorError.invalidLocation
        }
        let coordinate = String(
            format: "%.7f,%.7f",
            locale: Locale(identifier: "en_US_POSIX"),
            latitude,
            longitude
        )
        return try mutate(
            action: "location-set",
            udid: udid,
            arguments: ["simctl", "location", udid, "set", coordinate]
        )
    }

    public static func clearLocation(udid: String) throws -> SimulatorActionResult {
        try mutate(
            action: "location-clear",
            udid: udid,
            arguments: ["simctl", "location", udid, "clear"]
        )
    }

    public static func recordVideo(
        udid: String,
        path: String,
        durationSeconds: Int,
        codec: String = "h264",
        display: String? = nil
    ) throws -> SimulatorRecordingResult {
        try validateMutationTarget(udid: udid)
        let destination = URL(fileURLWithPath: path)
        guard !path.isEmpty, path.utf8.count <= 4_096, !path.contains("\0"),
              destination.path.hasPrefix("/"),
              !FileManager.default.fileExists(atPath: destination.path),
              (1...60).contains(durationSeconds),
              ["h264", "hevc"].contains(codec),
              display.map({ !$0.isEmpty && $0.utf8.count <= 256 && !$0.contains("\0") }) ?? true else {
            throw SimulatorError.invalidRecordingRequest
        }

        var arguments = ["simctl", "io", udid, "recordVideo", "--codec=\(codec)"]
        if let display { arguments += ["--display=\(display)"] }
        arguments.append(destination.path)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            Thread.sleep(forTimeInterval: TimeInterval(durationSeconds))
            if process.isRunning {
                _ = Darwin.kill(process.processIdentifier, SIGINT)
            }
            process.waitUntilExit()
        } catch {
            throw SimulatorError.commandFailed(error.localizedDescription)
        }
        guard FileManager.default.fileExists(atPath: destination.path),
              let attributes = try? FileManager.default.attributesOfItem(atPath: destination.path),
              let size = attributes[.size] as? NSNumber,
              size.intValue > 0 else {
            throw SimulatorError.commandFailed("simctl recordVideo did not produce a non-empty video file.")
        }
        return SimulatorRecordingResult(
            udid: udid,
            path: destination.path,
            durationSeconds: durationSeconds,
            codec: codec
        )
    }

    public static func appInfo(udid: String, bundleID: String) throws -> SimulatorAppInfoResult {
        guard try list().contains(where: { $0.udid == udid }) else {
            throw SimulatorError.unknownDevice(udid)
        }
        let result = try run(arguments: ["simctl", "appinfo", udid, bundleID])
        return SimulatorAppInfoResult(udid: udid, bundleID: bundleID, output: result.stdout)
    }

    public static func appContainer(
        udid: String,
        bundleID: String,
        container: String
    ) throws -> SimulatorContainerResult {
        guard ["app", "data", "groups"].contains(container) || !container.contains("\0") else {
            throw SimulatorError.invalidLaunchArguments
        }
        guard try list().contains(where: { $0.udid == udid }) else {
            throw SimulatorError.unknownDevice(udid)
        }
        let result = try run(arguments: ["simctl", "get_app_container", udid, bundleID, container])
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return SimulatorContainerResult(udid: udid, bundleID: bundleID, container: container, path: path)
    }

    private static func mutate(
        action: String,
        udid: String,
        arguments: [String]
    ) throws -> SimulatorActionResult {
        try validateMutationTarget(udid: udid)
        let result = try run(arguments: arguments)
        return SimulatorActionResult(action: action, udid: udid, output: result.stdout)
    }

    private static func validateMutationTarget(udid: String) throws {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION"] == "1" else {
            throw SimulatorError.mutationDisabled
        }
        guard try list().contains(where: { $0.udid == udid }) else {
            throw SimulatorError.unknownDevice(udid)
        }
    }

    private struct CommandResult {
        let stdout: String
        let stderr: String
    }

    private static func run(arguments: [String]) throws -> CommandResult {
        let result: AppleProcessResult
        do {
            result = try AppleProcessRunner.run(
                executable: "/usr/bin/xcrun",
                arguments: arguments,
                maximumOutputSize: 8 * 1024 * 1024
            )
        } catch AppleProcessRunnerError.launchFailed(let message) {
            throw SimulatorError.commandFailed(message)
        } catch AppleProcessRunnerError.outputTooLarge {
            throw SimulatorError.commandFailed("Simulator command output exceeds the 8 MB analysis limit.")
        } catch {
            throw SimulatorError.commandFailed(error.localizedDescription)
        }

        let stdout = String(decoding: result.stdout, as: UTF8.self)
        let stderr = String(decoding: result.stderr, as: UTF8.self)
        guard result.terminationStatus == 0 else {
            throw SimulatorError.commandFailed(
                stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? stdout : stderr
            )
        }
        return CommandResult(stdout: stdout, stderr: stderr)
    }
}
