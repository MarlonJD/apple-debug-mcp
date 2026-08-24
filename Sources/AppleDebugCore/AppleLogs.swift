// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum AppleLogError: Error, Equatable, LocalizedError, Sendable {
    case invalidTarget
    case invalidDuration
    case invalidPredicate
    case targetNotFound(String)
    case commandFailed(String)
    case outputTooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidTarget:
            return "Log target must be host or an available iOS Simulator UDID."
        case .invalidDuration:
            return "Log duration must use a bounded form such as 30s, 5m, 1h, or 1d."
        case .invalidPredicate:
            return "Log predicate must be a single line no longer than 512 characters."
        case .targetNotFound(let target):
            return "Log target is not in the available Simulator inventory: \(target)"
        case .commandFailed(let message):
            return "log show command failed: \(message)"
        case .outputTooLarge:
            return "Log output exceeds the 2 MB response limit. Narrow the duration or predicate."
        }
    }
}

public struct AppleLogResult: Codable, Equatable, Sendable {
    public let target: String
    public let last: String
    public let predicate: String?
    public let output: String

    public init(target: String, last: String, predicate: String?, output: String) {
        self.target = target
        self.last = last
        self.predicate = predicate
        self.output = output
    }
}

public enum AppleLogService {
    private static let maximumOutputSize = 2 * 1024 * 1024

    public static func show(
        target: String = "host",
        last: String = "5m",
        predicate: String? = nil
    ) throws -> AppleLogResult {
        let normalizedLast = try validateDuration(last)
        try validatePredicate(predicate)

        let executable: String
        let arguments: [String]
        if target == "host" {
            executable = "/usr/bin/log"
            arguments = ["show", "--last", normalizedLast, "--style", "json"]
        } else {
            guard try SimulatorService.list().contains(where: { $0.udid == target }) else {
                throw AppleLogError.targetNotFound(target)
            }
            executable = "/usr/bin/xcrun"
            arguments = [
                "simctl", "spawn", target,
                "log", "show", "--last", normalizedLast, "--style", "json"
            ]
        }

        var commandArguments = arguments
        if let predicate {
            commandArguments += ["--predicate", predicate]
        }
        let output = try run(executable: executable, arguments: commandArguments)
        return AppleLogResult(
            target: target,
            last: normalizedLast,
            predicate: predicate,
            output: output
        )
    }

    private static func validateDuration(_ value: String) throws -> String {
        guard let unit = value.last,
              ["s", "m", "h", "d"].contains(unit),
              let amount = Int(value.dropLast()),
              amount > 0 else {
            throw AppleLogError.invalidDuration
        }
        let multiplier: Int
        switch unit {
        case "s": multiplier = 1
        case "m": multiplier = 60
        case "h": multiplier = 60 * 60
        default: multiplier = 24 * 60 * 60
        }
        guard amount <= 86_400 / multiplier else {
            throw AppleLogError.invalidDuration
        }
        return value
    }

    private static func validatePredicate(_ value: String?) throws {
        guard let value else { return }
        guard !value.isEmpty, value.count <= 512, !value.contains("\n"), !value.contains("\r") else {
            throw AppleLogError.invalidPredicate
        }
    }

    private static func run(executable: String, arguments: [String]) throws -> String {
        let result: AppleProcessResult
        do {
            result = try AppleProcessRunner.run(
                executable: executable,
                arguments: arguments,
                maximumOutputSize: maximumOutputSize
            )
        } catch AppleProcessRunnerError.outputTooLarge {
            throw AppleLogError.outputTooLarge
        } catch AppleProcessRunnerError.launchFailed(let message) {
            throw AppleLogError.commandFailed(message)
        } catch {
            throw AppleLogError.commandFailed(error.localizedDescription)
        }
        let stdout = String(decoding: result.stdout, as: UTF8.self)
        let stderr = String(decoding: result.stderr, as: UTF8.self)
        guard result.terminationStatus == 0 else {
            throw AppleLogError.commandFailed(
                stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? stdout : stderr
            )
        }
        return stdout
    }
}
