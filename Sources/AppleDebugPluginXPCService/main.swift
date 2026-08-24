// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppleDebugCore
import Foundation

private final class AppleDebugPluginXPCService: NSObject, NSXPCListenerDelegate, AppleDebugPluginXPCProtocol {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: AppleDebugPluginXPCProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    func analyze(
        pluginExecutablePath: String,
        manifestData: Data,
        inputData: Data,
        timeoutSeconds: Double,
        reply: @escaping (Data?, String?) -> Void
    ) {
        do {
            guard timeoutSeconds.isFinite, (0.1...30.0).contains(timeoutSeconds),
                  manifestData.count <= 64 * 1024,
                  inputData.count <= 256 * 1024 else {
                throw ApplePluginHostError.invalidRequest
            }
            let manifest = try JSONDecoder().decode(AppleDebugPluginManifest.self, from: manifestData)
            guard !manifest.id.isEmpty, !manifest.name.isEmpty, !manifest.version.isEmpty else {
                throw ApplePluginHostError.invalidRequest
            }
            guard Bundle.main.bundleIdentifier == manifest.id else {
                throw ApplePluginHostError.invalidRequest
            }
            guard let input = String(data: inputData, encoding: .utf8),
                  !input.contains("\0") else {
                throw ApplePluginHostError.invalidRequest
            }
            let result = ApplePluginHostExecutionResult(
                pluginID: manifest.id,
                executablePath: pluginExecutablePath,
                sandboxed: true,
                exitCode: 0,
                timedOut: false,
                stdout: input,
                stderr: "",
                notes: [
                    "This fixture implements AppleDebugPluginXPCProtocol inside its own signed App Sandbox XPC service.",
                    "A production third-party plugin supplies its own analyze implementation in the same independently signed XPC boundary.",
                    "No child process, sandbox-exec profile, or in-process dylib loading is used."
                ]
            )
            reply(try JSONEncoder().encode(result), nil)
        } catch {
            reply(nil, error.localizedDescription)
        }
    }
}

let listener = NSXPCListener.service()
private let delegate = AppleDebugPluginXPCService()
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
