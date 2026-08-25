// Apple Debug MCP Menu Bar
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Darwin
import Foundation

@MainActor
final class MCPServerController {
    enum State: Equatable {
        case stopped
        case starting
        case running(Int32)
        case stopping
        case failed(String)
    }

    var onStateChange: ((State) -> Void)?
    private(set) var state: State = .stopped {
        didSet { onStateChange?(state) }
    }

    private var process: Process?
    private var inputWriter: FileHandle?
    private var outputHandle: FileHandle?
    private var errorHandle: FileHandle?

    var logURL: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/AppleDebugMCP/server.log")
    }

    func start() throws {
        guard process?.isRunning != true else { return }
        guard let executableURL = resolveServerURL() else {
            let message = "Bundled apple-debug-mcp executable was not found."
            state = .failed(message)
            throw MCPServerControllerError.executableNotFound
        }

        state = .starting
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
            throw error
        }

        self.process = process
        self.inputWriter = inputPipe.fileHandleForWriting
        self.outputHandle = outputHandle
        self.errorHandle = errorHandle
        state = .running(process.processIdentifier)
    }

    func stop() {
        guard let process else {
            state = .stopped
            return
        }
        let writer = inputWriter
        inputWriter = nil
        try? writer?.close()
        if process.isRunning {
            state = .stopping
            process.terminate()
            let processID = process.processIdentifier
            Task { @MainActor [weak self, weak process] in
                try? await Task.sleep(for: .seconds(1))
                guard let process, process.isRunning else { return }
                _ = kill(processID, SIGKILL)
                self?.state = .stopping
            }
        } else {
            handleTermination(status: process.terminationStatus)
        }
    }

    private func handleTermination(status: Int32) {
        try? outputHandle?.close()
        try? errorHandle?.close()
        outputHandle = nil
        errorHandle = nil
        inputWriter = nil
        process = nil
        if status == 0 || status == SIGTERM || status == SIGKILL {
            state = .stopped
        } else {
            state = .failed("exit status \(status)")
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

enum MCPServerControllerError: Error, LocalizedError {
    case executableNotFound

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "The bundled apple-debug-mcp executable was not found."
        }
    }
}
