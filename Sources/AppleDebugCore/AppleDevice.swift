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
    case invalidProcessID
    case invalidSignal
    case invalidPath
    case coreDeviceOnly(String)
    case legacyToolUnavailable(String)
    case legacyDebugRequiresAppPath
    case legacyDebugUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return "Apple physical-device command failed: \(message)"
        case .invalidResponse:
            return "Apple physical-device tooling returned an invalid device inventory."
        case .mutationDisabled:
            return "Physical-device mutation is disabled. Set APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1 for an authorized workflow."
        case .debugDisabled:
            return "Physical-device debugging is disabled. Set APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1 for an authorized workflow."
        case .unknownDevice(let identifier):
            return "Device is not in the Apple device inventory: \(identifier)"
        case .invalidIdentifier:
            return "Physical-device debugging requires a CoreDevice UUID or a 40-character legacy device UDID."
        case .deviceNotAuthorized(let identifier):
            return "Device is not paired and tunnel-ready for authorized development: \(identifier)"
        case .appNotFound:
            return "Application bundle was not found."
        case .invalidProcessID:
            return "Physical-device process ID must be a positive integer."
        case .invalidSignal:
            return "Physical-device signal is not in the supported signal allowlist."
        case .invalidPath:
            return "Physical-device output path must be absolute, bounded, and have an existing parent directory."
        case .coreDeviceOnly(let operation):
            return "Physical-device operation is available only through CoreDevice: \(operation)"
        case .legacyToolUnavailable(let tool):
            return "Legacy Xcode device transport is available, but \(tool) is not installed."
        case .legacyDebugRequiresAppPath:
            return "Legacy physical-device LLDB-DAP requires the signed .app path when creating the debug session."
        case .legacyDebugUnavailable(let identifier):
            return "LLDB-DAP cannot attach through the legacy Xcode transport for this device: \(identifier)."
        }
    }
}

public enum AppleDeviceTransport: String, Codable, Equatable, Sendable {
    case coreDevice = "coredevice"
    case legacyXcode = "legacy-xcode"
}

public struct AppleDeviceSummary: Codable, Equatable, Sendable {
    public let identifier: String
    public let productType: String
    public let platform: String
    public let bootState: String
    public let pairingState: String
    public let tunnelState: String
    public let deviceUDID: String?
    public let transport: AppleDeviceTransport
    public let isAuthorizedForDevelopment: Bool

    public init(
        identifier: String,
        productType: String,
        platform: String,
        bootState: String,
        pairingState: String,
        tunnelState: String,
        deviceUDID: String? = nil,
        transport: AppleDeviceTransport = .coreDevice
    ) {
        self.identifier = identifier
        self.productType = productType
        self.platform = platform
        self.bootState = bootState
        self.pairingState = pairingState
        self.tunnelState = tunnelState
        self.deviceUDID = deviceUDID
        self.transport = transport
        self.isAuthorizedForDevelopment = switch transport {
        case .coreDevice:
            pairingState == "paired"
                && ["connected", "available"].contains(tunnelState.lowercased())
        case .legacyXcode:
            pairingState == "legacy-available"
        }
    }
}

public struct AppleDeviceActionResult: Codable, Equatable, Sendable {
    public let action: String
    public let identifier: String
    public let output: String
    public let processID: Int?

    public init(action: String, identifier: String, output: String, processID: Int? = nil) {
        self.action = action
        self.identifier = identifier
        self.output = output
        self.processID = processID
    }
}

public struct AppleDeviceProcess: Codable, Equatable, Sendable {
    public let processID: Int
    public let executable: String
    public let name: String

    public init(processID: Int, executable: String, name: String) {
        self.processID = processID
        self.executable = executable
        self.name = name
    }
}

public struct AppleDeviceSysdiagnoseResult: Codable, Equatable, Sendable {
    public let identifier: String
    public let destination: String?
    public let fullLogs: Bool
    public let output: String

    public init(identifier: String, destination: String?, fullLogs: Bool, output: String) {
        self.identifier = identifier
        self.destination = destination
        self.fullLogs = fullLogs
        self.output = output
    }
}

public enum AppleDeviceService {
    public static func list() throws -> [AppleDeviceSummary] {
        var devices: [AppleDeviceSummary] = []
        var coreDeviceError: Error?
        do {
            devices.append(contentsOf: refreshCoreDeviceTunnels(try listCoreDevices()))
        } catch {
            coreDeviceError = error
        }
        if let legacyDevices = try? listLegacyDevices() {
            devices.append(contentsOf: legacyDevices)
        }
        if !devices.isEmpty {
            return devices.sorted {
                if $0.transport != $1.transport {
                    return $0.transport.rawValue < $1.transport.rawValue
                }
                return $0.identifier < $1.identifier
            }
        }
        if let coreDeviceError {
            throw coreDeviceError
        }
        return []
    }

    public static func device(identifier: String) throws -> AppleDeviceSummary {
        guard isSupportedIdentifier(identifier) else {
            throw AppleDeviceError.invalidIdentifier
        }
        guard let device = try list().first(where: { $0.identifier == identifier }) else {
            throw AppleDeviceError.unknownDevice(identifier)
        }
        guard device.isAuthorizedForDevelopment else {
            throw AppleDeviceError.deviceNotAuthorized(identifier)
        }
        return device
    }

    private static func listCoreDevices() throws -> [AppleDeviceSummary] {
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

    private static func refreshCoreDeviceTunnels(_ devices: [AppleDeviceSummary]) -> [AppleDeviceSummary] {
        devices.map { device in
            guard device.transport == .coreDevice,
                  device.pairingState.caseInsensitiveCompare("paired") == .orderedSame,
                  !["connected", "available"].contains(device.tunnelState.lowercased()) else {
                return device
            }

            do {
                _ = try run(arguments: [
                    "devicectl", "device", "info", "lockState",
                    "--device", device.identifier,
                    "--quiet"
                ])
                return AppleDeviceSummary(
                    identifier: device.identifier,
                    productType: device.productType,
                    platform: device.platform,
                    bootState: device.bootState,
                    pairingState: device.pairingState,
                    tunnelState: "connected",
                    deviceUDID: device.deviceUDID,
                    transport: device.transport
                )
            } catch {
                return device
            }
        }
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
                tunnelState: connection["tunnelState"] as? String ?? "unknown",
                deviceUDID: hardware["udid"] as? String,
                transport: .coreDevice
            )
        }
        .sorted { $0.identifier < $1.identifier }
    }

    public static func parseLegacyInventory(data: Data) throws -> [AppleDeviceSummary] {
        guard let devices = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw AppleDeviceError.invalidResponse
        }
        return devices.compactMap { device in
            guard (device["simulator"] as? Bool) != true,
                  let platform = device["platform"] as? String,
                  platform.localizedCaseInsensitiveContains("iphoneos"),
                  let identifier = device["identifier"] as? String,
                  isSupportedIdentifier(identifier) else {
                return nil
            }
            let available = device["available"] as? Bool ?? false
            return AppleDeviceSummary(
                identifier: identifier,
                productType: device["modelCode"] as? String ?? device["modelName"] as? String ?? "unknown",
                platform: "iOS",
                bootState: available ? "available" : "unavailable",
                pairingState: available ? "legacy-available" : "legacy-unavailable",
                tunnelState: "not-required",
                deviceUDID: identifier,
                transport: .legacyXcode
            )
        }
        .sorted { $0.identifier < $1.identifier }
    }

    private static func listLegacyDevices() throws -> [AppleDeviceSummary] {
        let output = try run(arguments: ["xcdevice", "list"])
        return try parseLegacyInventory(data: Data(output.stdout.utf8))
    }

    public static func install(identifier: String, appPath: String) throws -> AppleDeviceActionResult {
        let device = try mutate(identifier: identifier)
        guard FileManager.default.fileExists(atPath: appPath) else {
            throw AppleDeviceError.appNotFound
        }
        if device.transport == .legacyXcode {
            return try legacyInstall(identifier: identifier, appPath: appPath)
        }
        let output = try run(arguments: [
            "devicectl", "device", "install", "app",
            "--device", identifier, appPath
        ])
        return AppleDeviceActionResult(action: "install", identifier: identifier, output: output.stdout)
    }

    public static func launch(identifier: String, bundleID: String, startStopped: Bool, appPath: String? = nil) throws -> AppleDeviceActionResult {
        let device = try mutate(identifier: identifier)
        if device.transport == .legacyXcode {
            guard let appPath else {
                throw AppleDeviceError.legacyToolUnavailable("ios-deploy (provide appPath for legacy launch)")
            }
            guard !startStopped else {
                throw AppleDeviceError.legacyDebugUnavailable(identifier)
            }
            return try legacyLaunch(identifier: identifier, appPath: appPath)
        }
        var arguments = [
            "devicectl", "device", "process", "launch",
            "--device", identifier
        ]
        if startStopped {
            arguments.append("--start-stopped")
        }
        arguments.append("--terminate-existing")
        arguments.append(bundleID)
        let output = try run(arguments: arguments)
        return AppleDeviceActionResult(
            action: "launch",
            identifier: identifier,
            output: output.stdout,
            processID: findProcessID(
                identifier: identifier,
                bundleID: bundleID,
                appPath: appPath
            )
        )
    }

    public static func processes(identifier: String) throws -> [AppleDeviceProcess] {
        let device = try device(identifier: identifier)
        guard device.transport == .coreDevice else {
            throw AppleDeviceError.coreDeviceOnly("process inventory")
        }
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        _ = try run(arguments: [
            "devicectl", "device", "info", "processes",
            "--device", identifier,
            "--json-output", outputURL.path,
            "--quiet"
        ])
        guard let data = try? Data(contentsOf: outputURL) else {
            throw AppleDeviceError.invalidResponse
        }
        return try parseProcessInventory(data: data)
    }

    public static func parseProcessInventory(data: Data) throws -> [AppleDeviceProcess] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["result"] as? [String: Any],
              let processes = result["runningProcesses"] as? [[String: Any]] else {
            throw AppleDeviceError.invalidResponse
        }
        return processes.compactMap { process in
            guard let processID = process["processIdentifier"] as? Int,
                  processID > 0,
                  let executable = process["executable"] as? String,
                  !executable.isEmpty else {
                return nil
            }
            let path = URL(string: executable)?.path ?? executable
            return AppleDeviceProcess(
                processID: processID,
                executable: executable,
                name: URL(fileURLWithPath: path).lastPathComponent
            )
        }
        .sorted { ($0.name, $0.processID) < ($1.name, $1.processID) }
    }

    public static func terminate(identifier: String, processID: Int, force: Bool = false) throws -> AppleDeviceActionResult {
        var arguments = ["devicectl", "device", "process", "terminate", "--device", identifier, "--pid", String(processID)]
        if force { arguments.append("--kill") }
        return try coreProcessAction(identifier: identifier, processID: processID, action: "terminate", arguments: arguments)
    }

    public static func suspend(identifier: String, processID: Int) throws -> AppleDeviceActionResult {
        try coreProcessAction(
            identifier: identifier,
            processID: processID,
            action: "suspend",
            arguments: ["devicectl", "device", "process", "suspend", "--device", identifier, "--pid", String(processID)]
        )
    }

    public static func resume(identifier: String, processID: Int) throws -> AppleDeviceActionResult {
        try coreProcessAction(
            identifier: identifier,
            processID: processID,
            action: "resume",
            arguments: ["devicectl", "device", "process", "resume", "--device", identifier, "--pid", String(processID)]
        )
    }

    public static func signal(identifier: String, processID: Int, signal: String) throws -> AppleDeviceActionResult {
        let normalizedSignal = try validateSignal(signal)
        return try coreProcessAction(
            identifier: identifier,
            processID: processID,
            action: "signal",
            arguments: [
                "devicectl", "device", "process", "signal",
                "--device", identifier,
                "--pid", String(processID),
                "--signal", normalizedSignal
            ]
        )
    }

    public static func sysdiagnose(
        identifier: String,
        destination: String,
        fullLogs: Bool = false
    ) throws -> AppleDeviceSysdiagnoseResult {
        let device = try mutate(identifier: identifier)
        guard device.transport == .coreDevice else {
            throw AppleDeviceError.coreDeviceOnly("sysdiagnose")
        }
        try validateOutputPath(destination)
        var arguments = [
            "devicectl", "device", "sysdiagnose",
            "--device", identifier,
            "--destination", destination
        ]
        if fullLogs { arguments.append("--gather-full-logs") }
        let output = try run(arguments: arguments)
        return AppleDeviceSysdiagnoseResult(
            identifier: identifier,
            destination: destination,
            fullLogs: fullLogs,
            output: output.stdout
        )
    }

    public static func validateAuthorizedDevice(identifier: String) throws {
        _ = try device(identifier: identifier)
    }

    private static func coreProcessAction(
        identifier: String,
        processID: Int,
        action: String,
        arguments: [String]
    ) throws -> AppleDeviceActionResult {
        let device = try mutate(identifier: identifier)
        guard device.transport == .coreDevice else {
            throw AppleDeviceError.coreDeviceOnly("process \(action)")
        }
        try validateProcessID(processID)
        let output = try run(arguments: arguments)
        return AppleDeviceActionResult(
            action: action,
            identifier: identifier,
            output: output.stdout,
            processID: processID
        )
    }

    private static func validateProcessID(_ processID: Int) throws {
        guard processID > 0 else {
            throw AppleDeviceError.invalidProcessID
        }
    }

    private static func validateSignal(_ signal: String) throws -> String {
        let normalized = signal.uppercased()
        let allowed = [
            "SIGHUP", "SIGINT", "SIGQUIT", "SIGILL", "SIGABRT", "SIGFPE", "SIGKILL",
            "SIGSEGV", "SIGPIPE", "SIGALRM", "SIGTERM", "SIGSTOP", "SIGCONT", "SIGUSR1", "SIGUSR2"
        ]
        guard allowed.contains(normalized) else {
            throw AppleDeviceError.invalidSignal
        }
        return normalized
    }

    private static func validateOutputPath(_ path: String) throws {
        guard !path.isEmpty,
              path.utf8.count <= 4_096,
              !path.contains("\0"),
              URL(fileURLWithPath: path).path.hasPrefix("/") else {
            throw AppleDeviceError.invalidPath
        }
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else { throw AppleDeviceError.invalidPath }
            return
        }
        let parent = URL(fileURLWithPath: path).deletingLastPathComponent().path
        guard fileManager.fileExists(atPath: parent, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw AppleDeviceError.invalidPath
        }
    }

    private static func mutate(identifier: String) throws -> AppleDeviceSummary {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_DEVICE_MUTATION"] == "1" else {
            throw AppleDeviceError.mutationDisabled
        }
        return try device(identifier: identifier)
    }

    private static func legacyInstall(identifier: String, appPath: String) throws -> AppleDeviceActionResult {
        guard let iosDeploy = legacyToolPath() else {
            throw AppleDeviceError.legacyToolUnavailable("ios-deploy (brew install ios-deploy)")
        }
        let output = try runExecutable(
            iosDeploy,
            arguments: ["--id", identifier, "--bundle", appPath]
        )
        return AppleDeviceActionResult(action: "install", identifier: identifier, output: output.stdout)
    }

    private static func legacyLaunch(identifier: String, appPath: String) throws -> AppleDeviceActionResult {
        guard let iosDeploy = legacyToolPath() else {
            throw AppleDeviceError.legacyToolUnavailable("ios-deploy (brew install ios-deploy)")
        }
        let output = try runExecutable(
            iosDeploy,
            arguments: ["--id", identifier, "--bundle", appPath, "--justlaunch"]
        )
        return AppleDeviceActionResult(action: "launch", identifier: identifier, output: output.stdout)
    }

    private static func findProcessID(identifier: String, bundleID: String, appPath: String?) -> Int? {
        let executableName = appPath.flatMap { bundleExecutableName(for: $0) }
            ?? bundleID.split(separator: ".").last.map(String.init)
        guard let executableName, !executableName.isEmpty else {
            return nil
        }

        for _ in 0..<20 {
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("apple-debug-mcp-\(UUID().uuidString).json")
            defer { try? FileManager.default.removeItem(at: outputURL) }
            do {
                _ = try run(arguments: [
                    "devicectl", "device", "info", "processes",
                    "--device", identifier,
                    "--json-output", outputURL.path,
                    "--quiet"
                ])
                let data = try Data(contentsOf: outputURL)
                guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let result = root["result"] as? [String: Any],
                      let processes = result["runningProcesses"] as? [[String: Any]] else {
                    return nil
                }
                if let process = processes.first(where: { process in
                    guard let executable = process["executable"] as? String,
                          let processID = process["processIdentifier"] as? Int else {
                        return false
                    }
                    let path = URL(string: executable)?.path ?? executable
                    return path.hasSuffix("/\(executableName)") && processID > 0
                }), let processID = process["processIdentifier"] as? Int {
                    return processID
                }
            } catch {
                return nil
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return nil
    }

    private static func bundleExecutableName(for appPath: String) -> String? {
        guard let bundle = Bundle(path: appPath),
              let name = bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String,
              !name.isEmpty else {
            return nil
        }
        return name
    }

    static func legacyToolPath() -> String? {
        if let path = ToolchainProbe.path(for: "ios-deploy") {
            return path
        }
        return ["/opt/homebrew/bin/ios-deploy", "/usr/local/bin/ios-deploy"]
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    }

    private static func runExecutable(_ executable: String, arguments: [String]) throws -> CommandResult {
        let result: AppleProcessResult
        do {
            result = try AppleProcessRunner.run(
                executable: executable,
                arguments: arguments,
                maximumOutputSize: 8 * 1024 * 1024
            )
        } catch AppleProcessRunnerError.launchFailed(let message) {
            throw AppleDeviceError.commandFailed(message)
        } catch AppleProcessRunnerError.outputTooLarge {
            throw AppleDeviceError.commandFailed("Legacy device output exceeds the 8 MB analysis limit.")
        } catch {
            throw AppleDeviceError.commandFailed(error.localizedDescription)
        }
        let stdout = String(decoding: result.stdout, as: UTF8.self)
        let stderr = String(decoding: result.stderr, as: UTF8.self)
        guard result.terminationStatus == 0 else {
            throw AppleDeviceError.commandFailed(
                stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? stdout : stderr
            )
        }
        return CommandResult(stdout: stdout, stderr: stderr)
    }

    private static func isSupportedIdentifier(_ identifier: String) -> Bool {
        if UUID(uuidString: identifier) != nil {
            return true
        }
        return identifier.utf8.count == 40 && identifier.allSatisfy(\.isHexDigit)
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
            throw AppleDeviceError.commandFailed(message)
        } catch AppleProcessRunnerError.outputTooLarge {
            throw AppleDeviceError.commandFailed("CoreDevice output exceeds the 8 MB analysis limit.")
        } catch {
            throw AppleDeviceError.commandFailed(error.localizedDescription)
        }

        let stdout = String(decoding: result.stdout, as: UTF8.self)
        let stderr = String(decoding: result.stderr, as: UTF8.self)
        guard result.terminationStatus == 0 else {
            throw AppleDeviceError.commandFailed(
                stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? stdout : stderr
            )
        }
        return CommandResult(stdout: stdout, stderr: stderr)
    }
}
