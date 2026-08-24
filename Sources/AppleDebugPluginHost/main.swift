// Apple Debug MCP Plugin Host
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppleDebugCore
import Darwin
import Foundation

@main
struct AppleDebugPluginHostMain {
    static func main() {
        do {
            let arguments = CommandLine.arguments
            let manifestPath = try value(for: "--manifest", in: arguments)
            let executablePath = try value(for: "--executable", in: arguments)
            let teamIdentifier = optionalValue(for: "--team-id", in: arguments)
            let timeout = Double(optionalValue(for: "--timeout", in: arguments) ?? "10") ?? 10
            let transport = optionalValue(for: "--transport", in: arguments) ?? "profile"
            let serviceName = optionalValue(for: "--service-name", in: arguments)
            let inputData = FileHandle.standardInput.readDataToEndOfFile()
            guard inputData.count <= 256 * 1024 else { throw ApplePluginHostError.invalidRequest }
            let input = String(decoding: inputData, as: UTF8.self)
            let result: ApplePluginHostExecutionResult
            switch transport {
            case "profile":
                result = try ApplePluginHostService.execute(
                    executablePath: executablePath,
                    manifestPath: manifestPath,
                    input: input,
                    requiredTeamIdentifier: teamIdentifier,
                    timeoutSeconds: timeout
                )
            case "xpc":
                guard let serviceName else { throw ApplePluginHostError.invalidRequest }
                result = try ApplePluginHostService.executeViaXPC(
                    serviceName: serviceName,
                    executablePath: executablePath,
                    manifestPath: manifestPath,
                    input: input,
                    requiredTeamIdentifier: teamIdentifier,
                    timeoutSeconds: timeout
                )
            default:
                throw ApplePluginHostError.invalidRequest
            }
            let output = try JSONEncoder().encode(result)
            FileHandle.standardOutput.write(output)
            FileHandle.standardOutput.write(Data("\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("apple-debug-plugin-host: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    private static func value(for flag: String, in arguments: [String]) throws -> String {
        guard let value = optionalValue(for: flag, in: arguments), !value.isEmpty else {
            throw ApplePluginHostError.invalidRequest
        }
        return value
    }

    private static func optionalValue(for flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.index(after: index) < arguments.endIndex else { return nil }
        return arguments[arguments.index(after: index)]
    }
}
