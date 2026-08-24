// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum AppleDeviceError: Error, Equatable, LocalizedError, Sendable {
    case commandFailed(String)
    case invalidResponse
    case mutationDisabled
    case debugDisabled
    case unknownDevice(String)
    case invalidIdentifier
    case deviceNotAuthorized(String)
    case appNotFound

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return "devicectl command failed: \(message)"
        case .invalidResponse:
            return "devicectl returned an invalid device inventory."
        case .mutationDisabled:
            return "Physical-device mutation is disabled. Set APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1 for an authorized workflow."
        case .debugDisabled:
            return "Physical-device debugging is disabled. Set APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1 for an authorized workflow."
        case .unknownDevice(let identifier):
            return "Device is not in the CoreDevice inventory: \(identifier)"
        case .invalidIdentifier:
            return "Physical-device debugging requires a UUID device identifier."
        case .deviceNotAuthorized(let identifier):
            return "Device is not paired and tunnel-ready for authorized development: \(identifier)"
        case .appNotFound:
            return "Application bundle was not found."
        }
    }
}

public struct AppleDeviceSummary: Codable, Equatable, Sendable {
    public let identifier: String
    public let productType: String
    public let platform: String
    public let bootState: String
    public let pairingState: String
    public let tunnelState: String
    public let isAuthorizedForDevelopment: Bool

    public init(
        identifier: String,
        productType: String,
        platform: String,
        bootState: String,
        pairingState: String,
        tunnelState: String
    ) {
        self.identifier = identifier
        self.productType = productType
        self.platform = platform
        self.bootState = bootState
        self.pairingState = pairingState
        self.tunnelState = tunnelState
        self.isAuthorizedForDevelopment = pairingState == "paired" && tunnelState != "unavailable"
    }
}

public struct AppleDeviceActionResult: Codable, Equatable, Sendable {
    public let action: String
    public let identifier: String
    public let output: String

    public init(action: String, identifier: String, output: String) {
        self.action = action
        self.identifier = identifier
        self.output = output
    }
}

public enum AppleDeviceService {
    public static func list() throws -> [AppleDeviceSummary] {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        _ = try run(arguments: [
            "devicectl", "list", "devices",
            "--json-output", outputURL.path,
            "--quiet"
        ])
        let data = try Data(contentsOf: outputURL)
        return try parseInventory(data: data)
    }

    public static func parseInventory(data: Data) throws -> [AppleDeviceSummary] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["result"] as? [String: Any],
              let devices = result["devices"] as? [[String: Any]] else {
            throw AppleDeviceError.invalidResponse
        }

        return devices.compactMap { device in
            guard let identifier = device["identifier"] as? String else {
                return nil
            }
            let hardware = device["hardwareProperties"] as? [String: Any] ?? [:]
            let properties = device["deviceProperties"] as? [String: Any] ?? [:]
            let connection = device["connectionProperties"] as? [String: Any] ?? [:]
            return AppleDeviceSummary(
                identifier: identifier,
                productType: hardware["productType"] as? String ?? "unknown",
                platform: hardware["platform"] as? String ?? "unknown",
                bootState: properties["bootState"] as? String ?? "unknown",
                pairingState: connection["pairingState"] as? String ?? "unknown",
                tunnelState: connection["tunnelState"] as? String ?? "unknown"
            )
        }
        .sorted { $0.identifier < $1.identifier }
    }

    public static func install(identifier: String, appPath: String) throws -> AppleDeviceActionResult {
        try mutate(identifier: identifier)
        guard FileManager.default.fileExists(atPath: appPath) else {
            throw AppleDeviceError.appNotFound
        }
        let output = try run(arguments: [
            "devicectl", "device", "install", "app",
            "--device", identifier, appPath
        ])
        return AppleDeviceActionResult(action: "install", identifier: identifier, output: output.stdout)
    }

    public static func launch(identifier: String, bundleID: String, startStopped: Bool) throws -> AppleDeviceActionResult {
        try mutate(identifier: identifier)
        var arguments = [
            "devicectl", "device", "process", "launch",
            "--device", identifier
        ]
        if startStopped {
            arguments.append("--start-stopped")
        }
        arguments.append(bundleID)
        let output = try run(arguments: arguments)
        return AppleDeviceActionResult(action: "launch", identifier: identifier, output: output.stdout)
    }

    public static func validateAuthorizedDevice(identifier: String) throws {
        guard UUID(uuidString: identifier) != nil else {
            throw AppleDeviceError.invalidIdentifier
        }
        guard let device = try list().first(where: { $0.identifier == identifier }) else {
            throw AppleDeviceError.unknownDevice(identifier)
        }
        guard device.isAuthorizedForDevelopment else {
            throw AppleDeviceError.deviceNotAuthorized(identifier)
        }
    }

    private static func mutate(identifier: String) throws {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_DEVICE_MUTATION"] == "1" else {
            throw AppleDeviceError.mutationDisabled
        }
        try validateAuthorizedDevice(identifier: identifier)
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
            throw AppleDeviceError.commandFailed(error.localizedDescription)
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
            throw AppleDeviceError.commandFailed(
                stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? stdout : stderr
            )
        }
        return CommandResult(stdout: stdout, stderr: stderr)
    }
}
