// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct LegacyDeviceDebugConfiguration: Sendable {
    let preInitCommands: [String]
    let attachCommands: [String]
}

struct LegacyDeviceDebugServerMetadata: Equatable, Sendable {
    let port: Int
    let remoteAppPath: String
}

/// Owns the legacy Xcode debugserver process started by ios-deploy.
///
/// CoreDevice cannot service older iOS devices such as iOS 15 hardware. The
/// supported fallback is the same debugserver path used by Xcode's legacy
/// device tooling: ios-deploy keeps the local port forward alive while LLDB
/// connects through a small, generated LLDB-Python command registered as a
/// DAP attach command.
actor LegacyDeviceDebugTransport {
    private let deviceIdentifier: String
    private let appPath: String
    private var process: Process?
    private var outputHandle: FileHandle?
    private var errorHandle: FileHandle?
    private var outputURL: URL?
    private var errorURL: URL?
    private var bridgeScriptURL: URL?
    private var configuration: LegacyDeviceDebugConfiguration?

    init(deviceIdentifier: String, appPath: String) {
        self.deviceIdentifier = deviceIdentifier
        self.appPath = appPath
    }

    func start() async throws -> LegacyDeviceDebugConfiguration {
        if let configuration {
            return configuration
        }

        guard FileManager.default.fileExists(atPath: appPath) else {
            throw AppleDeviceError.appNotFound
        }
        guard let iosDeploy = AppleDeviceService.legacyToolPath() else {
            throw AppleDeviceError.legacyToolUnavailable("ios-deploy (brew install ios-deploy)")
        }

        let executableName = try executableName(for: appPath)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-ios-deploy-\(UUID().uuidString).stdout")
        let errorURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-ios-deploy-\(UUID().uuidString).stderr")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: iosDeploy)
        process.arguments = [
            "--id", deviceIdentifier,
            "--bundle", appPath,
            "--nolldb",
            "--no-wifi"
        ]

        do {
            let outputHandle = try FileHandle(forWritingTo: outputURL)
            let errorHandle = try FileHandle(forWritingTo: errorURL)
            process.standardOutput = outputHandle
            process.standardError = errorHandle
            try process.run()
            self.process = process
            self.outputHandle = outputHandle
            self.errorHandle = errorHandle
            self.outputURL = outputURL
            self.errorURL = errorURL
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            try? FileManager.default.removeItem(at: errorURL)
            throw AppleDeviceError.commandFailed("Unable to start ios-deploy: \(error.localizedDescription)")
        }

        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            let output = combinedOutput()
            guard output.utf8.count <= 8 * 1024 * 1024 else {
                stop()
                throw AppleDeviceError.commandFailed("ios-deploy output exceeds the 8 MB safety limit.")
            }

            if let metadata = Self.parseDebugServerOutput(output) {
                let scriptURL = try writeBridgeScript(
                    port: metadata.port,
                    remoteAppPath: metadata.remoteAppPath,
                    executableName: executableName
                )
                let configuration = LegacyDeviceDebugConfiguration(
                    preInitCommands: preInitCommands(
                        scriptPath: scriptURL.path
                    ),
                    attachCommands: ["apple_debug_mcp_legacy_attach"]
                )
                self.bridgeScriptURL = scriptURL
                self.configuration = configuration
                return configuration
            }

            if !process.isRunning {
                stop()
                let detail = output.trimmingCharacters(in: .whitespacesAndNewlines)
                throw AppleDeviceError.commandFailed(
                    detail.isEmpty ? "ios-deploy exited before opening a debugserver port." : detail
                )
            }

            try await Task.sleep(for: .milliseconds(50))
        }

        let detail = combinedOutput().trimmingCharacters(in: .whitespacesAndNewlines)
        stop()
        throw AppleDeviceError.commandFailed(
            detail.isEmpty
                ? "ios-deploy did not expose a legacy debugserver port within 30 seconds."
                : "ios-deploy did not expose a legacy debugserver port within 30 seconds: \(detail)"
        )
    }

    func stop() {
        if let process {
            if process.isRunning {
                process.terminate()
                if process.isRunning {
                    _ = Darwin.kill(process.processIdentifier, SIGKILL)
                }
                process.waitUntilExit()
            }
        }
        try? outputHandle?.close()
        try? errorHandle?.close()
        if let outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
        if let errorURL {
            try? FileManager.default.removeItem(at: errorURL)
        }
        if let bridgeScriptURL {
            try? FileManager.default.removeItem(at: bridgeScriptURL)
        }
        process = nil
        outputHandle = nil
        errorHandle = nil
        outputURL = nil
        errorURL = nil
        bridgeScriptURL = nil
        configuration = nil
    }

    private func combinedOutput() -> String {
        let stdout = outputURL.flatMap { try? Data(contentsOf: $0) } ?? Data()
        let stderr = errorURL.flatMap { try? Data(contentsOf: $0) } ?? Data()
        var combined = stdout
        combined.append(Data("\n".utf8))
        combined.append(stderr)
        return String(decoding: combined, as: UTF8.self)
    }

    static func parseDebugServerOutput(_ output: String) -> LegacyDeviceDebugServerMetadata? {
        guard let value = parseValue(after: "debugserver port:", from: output),
              let port = Int(value),
              (1...65_535).contains(port),
              let remoteAppPath = parseValue(after: "App path:", from: output) else {
            return nil
        }
        return LegacyDeviceDebugServerMetadata(port: port, remoteAppPath: remoteAppPath)
    }

    private static func parseValue(after prefix: String, from output: String) -> String? {
        for rawLine in output.split(whereSeparator: \.isNewline).reversed() {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix(prefix) else { continue }
            let value = String(line.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func executableName(for appPath: String) throws -> String {
        let infoURL = URL(fileURLWithPath: appPath).appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: infoURL)
        let propertyList = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )
        guard let info = propertyList as? [String: Any],
              let executable = info["CFBundleExecutable"] as? String,
              !executable.isEmpty,
              executable.utf8.count <= 512,
              !executable.contains("/"),
              !executable.contains("\\") else {
            throw AppleDeviceError.commandFailed("The app bundle does not expose a safe CFBundleExecutable name.")
        }
        return executable
    }

    private func writeBridgeScript(
        port: Int,
        remoteAppPath: String,
        executableName: String
    ) throws -> URL {
        let moduleName = "apple_debug_mcp_legacy_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(moduleName).py")
        let remoteExecutable = URL(fileURLWithPath: remoteAppPath)
            .appendingPathComponent(executableName)
            .path
        let script = """
        # Generated by Apple Debug MCP; removed with the owning session.
        import lldb
        import threading

        CONNECT_URL = \(pythonLiteral("connect://127.0.0.1:\(port)"))
        REMOTE_APP = \(pythonLiteral(remoteExecutable))

        LISTENER = None
        PROCESS = None

        def forward_process_events(debugger):
            while True:
                event = lldb.SBEvent()
                if not LISTENER.WaitForEvent(1, event):
                    continue
                debugger.GetListener().AddEvent(event)
                if lldb.SBProcess.EventIsProcessEvent(event):
                    state = lldb.SBProcess.GetStateFromEvent(event)
                    if state in (lldb.eStateExited, lldb.eStateDetached, lldb.eStateCrashed):
                        return

        def legacy_attach(debugger, command, result, internal_dict):
            global LISTENER, PROCESS
            target = debugger.GetSelectedTarget()
            if not target.IsValid():
                result.SetError("no selected LLDB target")
                return
            modules = target.modules
            if len(modules) == 0:
                result.SetError("target has no executable module")
                return
            modules[0].SetPlatformFileSpec(lldb.SBFileSpec(REMOTE_APP))
            LISTENER = lldb.SBListener("apple_debug_mcp_legacy")
            LISTENER.StartListeningForEventClass(
                debugger,
                lldb.SBProcess.GetBroadcasterClassName(),
                lldb.SBProcess.eBroadcastBitStateChanged | lldb.SBProcess.eBroadcastBitSTDOUT | lldb.SBProcess.eBroadcastBitSTDERR,
            )
            error = lldb.SBError()
            PROCESS = target.ConnectRemote(LISTENER, CONNECT_URL, None, error)
            if not error.Success():
                result.SetError(error.GetCString() or "legacy debugserver connection failed")
                return
            events = []
            state = PROCESS.GetState() or lldb.eStateInvalid
            while state != lldb.eStateConnected:
                event = lldb.SBEvent()
                if LISTENER.WaitForEvent(1, event):
                    state = PROCESS.GetStateFromEvent(event)
                    events.append(event)
                else:
                    state = lldb.eStateInvalid
                if state == lldb.eStateInvalid:
                    result.SetError("legacy debugserver did not reach the connected state")
                    return
            debugger_listener = debugger.GetListener()
            debugger_listener.StartListeningForEventClass(
                debugger,
                lldb.SBProcess.GetBroadcasterClassName(),
                lldb.SBProcess.eBroadcastBitStateChanged | lldb.SBProcess.eBroadcastBitSTDOUT | lldb.SBProcess.eBroadcastBitSTDERR,
            )
            for event in events:
                debugger_listener.AddEvent(event)
            launch_info = lldb.SBLaunchInfo([])
            launch_info.SetListener(LISTENER)
            launch_info.SetLaunchFlags(lldb.eLaunchFlagStopAtEntry)
            PROCESS = target.Launch(launch_info, error)
            if not error.Success():
                result.SetError(error.GetCString() or "legacy remote launch failed")
                return
            threading.Thread(target=forward_process_events, args=(debugger,), daemon=True).start()
            result.AppendMessage("legacy process state %s pid %s" % (PROCESS.GetState(), PROCESS.GetProcessID()))

        def __lldb_init_module(debugger, internal_dict):
            debugger.HandleCommand("command script add -f \(moduleName).legacy_attach apple_debug_mcp_legacy_attach")
        """
        guard FileManager.default.createFile(
            atPath: scriptURL.path,
            contents: Data(script.utf8)
        ) else {
            throw AppleDeviceError.commandFailed("Unable to create the temporary legacy LLDB bridge script.")
        }
        return scriptURL
    }

    private func preInitCommands(scriptPath: String) -> [String] {
        [
            "platform select remote-ios",
            "target create \(lldbQuote(appPath))",
            "command script import \(lldbQuote(scriptPath))"
        ]
    }

    private func pythonLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "'\(escaped)'"
    }

    private func lldbQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "\\\\'"))'"
    }
}
