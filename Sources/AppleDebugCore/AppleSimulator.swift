// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum SimulatorError: Error, Equatable, LocalizedError, Sendable {
    case commandFailed(String)
    case mutationDisabled
    case unknownDevice(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return "Simulator command failed: \(message)"
        case .mutationDisabled:
            return "Simulator mutation is disabled. Set APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1 for an authorized local workflow."
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
        try mutate(action: "boot", udid: udid, arguments: ["simctl", "boot", udid])
    }

    public static func shutdown(udid: String) throws -> SimulatorActionResult {
        try mutate(action: "shutdown", udid: udid, arguments: ["simctl", "shutdown", udid])
    }

    public static func install(udid: String, appPath: String) throws -> SimulatorActionResult {
        try mutate(action: "install", udid: udid, arguments: ["simctl", "install", udid, appPath])
    }

    public static func launch(udid: String, bundleID: String) throws -> SimulatorActionResult {
        try mutate(action: "launch", udid: udid, arguments: ["simctl", "launch", udid, bundleID])
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
            .appendingPathComponent("apple-debug-mcp-(UUID().uuidString).png")
            .path
        let result = try run(arguments: ["simctl", "io", udid, "screenshot", destination])
        return SimulatorActionResult(action: "screenshot", udid: udid, output: result.stdout.isEmpty ? destination : result.stdout)
    }

    private static func mutate(
        action: String,
        udid: String,
        arguments: [String]
    ) throws -> SimulatorActionResult {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION"] == "1" else {
            throw SimulatorError.mutationDisabled
        }
        guard try list().contains(where: { $0.udid == udid }) else {
            throw SimulatorError.unknownDevice(udid)
        }
        let result = try run(arguments: arguments)
        return SimulatorActionResult(action: action, udid: udid, output: result.stdout)
    }

    private struct CommandResult {
        let stdout: String
        let stderr: String
    }

    private static func run(arguments: [String]) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw SimulatorError.commandFailed(error.localizedDescription)
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
            throw SimulatorError.commandFailed(
                stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? stdout : stderr
            )
        }
        return CommandResult(stdout: stdout, stderr: stderr)
    }
}
