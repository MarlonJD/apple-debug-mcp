// Apple Debug MCP Menu Bar
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppleDebugCore
import Darwin
import Foundation
import OSLog

@MainActor
final class MCPServerController {
    enum State: Equatable {
        case stopped
        case starting
        case running(Int32, URL)
        case stopping
        case failed(String)
    }

    var onStateChange: ((State) -> Void)?
    private(set) var state: State = .stopped {
        didSet {
            onStateChange?(state)
            logger.info("MCP server state changed: \(self.state.label, privacy: .public)")
        }
    }

    private var process: Process?
    private var inputWriter: FileHandle?
    private var outputHandle: FileHandle?
    private var errorHandle: FileHandle?
    private var readinessTask: Task<Void, Never>?
    private var pendingFailure: String?
    private(set) var endpoint: AppleDebugDaemonEndpoint?
    private let logger = Logger(
        subsystem: "com.burakkarahan.apple-debug-menubar",
        category: "MCPServer"
    )

    var logURL: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/AppleDebugMCP/server.log")
    }

    func start() throws {
        guard process?.isRunning != true else { return }
        logger.info("Bundled MCP daemon start requested")
        guard let executableURL = resolveServerURL() else {
            let message = "Bundled apple-debug-mcp executable was not found."
            state = .failed(message)
            logger.error("Bundled MCP daemon executable was not found")
            throw MCPServerControllerError.executableNotFound
        }

        state = .starting
        pendingFailure = nil
        endpoint = nil
        let logDirectory = logURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }

        let inputPipe = Pipe()
        let outputHandle = try FileHandle(forWritingTo: logURL)
        let errorHandle = try FileHandle(forWritingTo: logURL)
        try outputHandle.seekToEnd()
        try errorHandle.seekToEnd()

        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["--daemon"]
        process.standardInput = inputPipe
        process.standardOutput = outputHandle
        process.standardError = errorHandle
        process.terminationHandler = { [weak self] process in
            Task { @MainActor [weak self] in
                self?.handleTermination(status: process.terminationStatus)
            }
        }

        do {
            try process.run()
        } catch {
            try? outputHandle.close()
            try? errorHandle.close()
            state = .failed(error.localizedDescription)
            logger.error("Bundled MCP daemon process failed to start: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        self.process = process
        self.inputWriter = inputPipe.fileHandleForWriting
        self.outputHandle = outputHandle
        self.errorHandle = errorHandle
        let processID = process.processIdentifier
        logger.info("Bundled MCP daemon process started with pid \(processID, privacy: .public)")
        readinessTask = Task { @MainActor [weak self] in
            await self?.waitForReady(processID: processID)
        }
    }

    func stop() {
        logger.info("Bundled MCP daemon stop requested")
        readinessTask?.cancel()
        readinessTask = nil
        guard let process else {
            state = .stopped
            return
        }
        let writer = inputWriter
        inputWriter = nil
        try? writer?.close()
        if process.isRunning {
            state = .stopping
            let processID = process.processIdentifier
            if let endpoint {
                Task { @MainActor [weak self] in
                    await self?.requestShutdown(endpoint)
                }
            }
            Task { @MainActor [weak self, weak process] in
                try? await Task.sleep(for: .seconds(2))
                guard let process, process.isRunning else { return }
                _ = kill(processID, SIGKILL)
                self?.state = .stopping
            }
        } else {
            handleTermination(status: process.terminationStatus)
        }
    }

    func stopImmediatelyForTermination() {
        readinessTask?.cancel()
        readinessTask = nil
        inputWriter = nil
        try? outputHandle?.close()
        try? errorHandle?.close()

        guard let process else {
            if let endpoint {
                AppleDebugDaemonEndpoint.removeIfOwned(pid: endpoint.pid, token: endpoint.token)
            }
            endpoint = nil
            state = .stopped
            return
        }

        process.terminationHandler = nil
        if process.isRunning {
            let processID = process.processIdentifier
            process.terminate()
            usleep(250_000)
            if process.isRunning {
                _ = kill(processID, SIGKILL)
            }
            process.waitUntilExit()
        }

        handleTermination(status: process.terminationStatus)
        logger.info("Bundled MCP daemon stopped during app termination")
    }

    private func requestShutdown(_ endpoint: AppleDebugDaemonEndpoint) async {
        var request = URLRequest(url: endpoint.shutdownURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 1
        request.setValue(endpoint.authorizationHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data()
        _ = try? await URLSession.shared.data(for: request)
    }

    private func handleTermination(status: Int32) {
        readinessTask?.cancel()
        readinessTask = nil
        if let endpoint {
            AppleDebugDaemonEndpoint.removeIfOwned(
                pid: endpoint.pid,
                token: endpoint.token
            )
        }
        endpoint = nil
        try? outputHandle?.close()
        try? errorHandle?.close()
        outputHandle = nil
        errorHandle = nil
        inputWriter = nil
        process = nil
        if let pendingFailure {
            self.pendingFailure = nil
            state = .failed(pendingFailure)
        } else if status == 0 || status == SIGTERM || status == SIGKILL {
            state = .stopped
        } else {
            state = .failed("exit status \(status)")
        }
    }

    private func waitForReady(processID: Int32) async {
        let deadline = Date().addingTimeInterval(8)
        while !Task.isCancelled, Date() < deadline {
            guard let process, process.processIdentifier == processID, process.isRunning else {
                return
            }

            if let candidate = try? AppleDebugDaemonEndpoint.load(),
                candidate.pid == processID,
                await isHealthy(candidate)
            {
                endpoint = candidate
                state = .running(processID, candidate.url)
                return
            }
            try? await Task.sleep(for: .milliseconds(100))
        }

        guard !Task.isCancelled else { return }
        pendingFailure = "MCP daemon did not publish a healthy local endpoint."
        logger.error("Bundled MCP daemon readiness timed out")
        stop()
    }

    private func isHealthy(_ endpoint: AppleDebugDaemonEndpoint) async -> Bool {
        var request = URLRequest(url: endpoint.healthURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 1
        request.setValue(endpoint.authorizationHeader, forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func resolveServerURL() -> URL? {
        let fileManager = FileManager.default
        var candidates: [URL] = []
        if let configured = ProcessInfo.processInfo.environment["APPLE_DEBUG_MCP_SERVER_PATH"], !configured.isEmpty {
            candidates.append(URL(fileURLWithPath: configured))
        }
        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("apple-debug-mcp"))
        }
        candidates.append(
            URL(fileURLWithPath: CommandLine.arguments[0])
                .deletingLastPathComponent()
                .appendingPathComponent("apple-debug-mcp")
        )
        candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/apple-debug-mcp"))
        candidates.append(URL(fileURLWithPath: "/usr/local/bin/apple-debug-mcp"))
        return candidates.first(where: { fileManager.isExecutableFile(atPath: $0.path) })
    }
}

private extension MCPServerController.State {
    var label: String {
        switch self {
        case .stopped: return "stopped"
        case .starting: return "starting"
        case .running: return "running"
        case .stopping: return "stopping"
        case .failed: return "failed"
        }
    }
}

enum MCPServerControllerError: Error, LocalizedError {
    case executableNotFound

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "The bundled apple-debug-mcp executable was not found."
        }
    }
}
