// Apple Debug MCP Workbench
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppleDebugCore
import Foundation
import SwiftUI

enum WorkbenchDebuggerState: String {
    case ready = "Ready"
    case session = "Session ready"
    case stopped = "Stopped"
    case running = "Running"
}

struct WorkbenchThreadRow: Identifiable {
    let id: Int
    let name: String
    let state: String
}

struct WorkbenchStackFrameRow: Identifiable {
    let id: Int
    let name: String
    let location: String
    let instructionPointer: String
}

struct WorkbenchRegisterRow: Identifiable {
    let id: String
    let name: String
    let value: String
}

@MainActor
final class WorkbenchModel: ObservableObject {
    enum Panel: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case debugger = "Debugger"
        case assembler = "Assembler"
        case controlFlow = "Control Flow"
        case performance = "Performance"
        case boundaries = "Boundaries"

        var id: String { rawValue }
    }

    @Published var panel: Panel = .overview
    @Published var targetPath = ""
    @Published var targetDisplayName = "No target selected"
    @Published var sessionID: String?
    @Published var debuggerState: WorkbenchDebuggerState = .ready
    @Published var isBusy = false
    @Published var debuggerOutput = ""
    @Published var debuggerThreadID = ""
    @Published var debuggerExpression = ""
    @Published var debuggerThreads: [WorkbenchThreadRow] = []
    @Published var debuggerStack: [WorkbenchStackFrameRow] = []
    @Published var debuggerRegisters: [WorkbenchRegisterRow] = []
    @Published var stopSnapshot: DebugStopSnapshot?
    @Published var architecture = "arm64"
    @Published var assemblySource = "mov x0, x0\nret\n"
    @Published var assemblyOutput = ""
    @Published var analysisPath = ""
    @Published var controlFlowOutput = ""
    @Published var controlFlowSummary = ""
    @Published var controlFlowFunctions: [ControlFlowFunction] = []
    @Published var controlFlowXrefs: [ControlFlowXref] = []
    @Published var tracePath = ""
    @Published var performanceSchema = "time-profile"
    @Published var performanceOutput = ""
    @Published var performanceSummary = ""
    @Published var comparisonTracePath = ""
    @Published var performanceDiffOutput = ""
    @Published var timelinePoints: [ApplePerformanceTimelinePoint] = []
    @Published var errorMessage: String?

    let capabilities = CapabilityMatrix.reports()
    private let sessions = DebugSessionManager()

    var hasTarget: Bool { !targetPath.isEmpty }

    var targetSummary: String {
        guard hasTarget else { return "Choose an authorized local executable to begin." }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: targetPath),
              let size = attributes[.size] as? NSNumber else {
            return targetPath
        }
        return "\(targetPath) · \(ByteCountFormatter.string(fromByteCount: size.int64Value, countStyle: .file))"
    }

    func setTarget(url: URL) {
        guard sessionID == nil else {
            errorMessage = "Close the current debugger session before choosing another target."
            return
        }
        let path = url.standardizedFileURL.path
        guard !path.isEmpty,
              let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let type = attributes[.type] as? FileAttributeType,
              type == .typeRegular else {
            errorMessage = "Choose an existing regular executable file."
            return
        }
        targetPath = path
        targetDisplayName = url.lastPathComponent
        errorMessage = nil
    }

    func clearTarget() {
        guard sessionID == nil else {
            errorMessage = "Close the current debugger session before clearing the target."
            return
        }
        targetPath = ""
        targetDisplayName = "No target selected"
        errorMessage = nil
    }

    func assemble() {
        do {
            let result = try AppleAssemblerService.assemble(source: assemblySource, architecture: architecture)
            assemblyOutput = "Bytes: \(result.bytesHex)\n\n\(result.disassembly)"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func analyzeControlFlow() {
        do {
            let report = try AppleControlFlowService.analyze(path: analysisPath, architecture: architecture)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            controlFlowOutput = String(decoding: try encoder.encode(report), as: UTF8.self)
            controlFlowSummary = "Functions: \(report.functions.count) · Blocks: \(report.functions.reduce(0) { $0 + $1.blocks.count }) · Xrefs: \(report.xrefs.count) · Relocations: \(report.relocations.count) · Indirect symbols: \(report.indirectSymbols.count)"
            controlFlowFunctions = report.functions
            controlFlowXrefs = report.xrefs
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func analyzePerformance() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            timelinePoints = []
            if performanceSchema == "swift-concurrency" {
                let graph = try AppleSwiftConcurrencyGraphService.analyze(tracePath: tracePath)
                performanceOutput = String(decoding: try encoder.encode(graph), as: UTF8.self)
                performanceSummary = "Swift Concurrency graph · Rows: \(graph.sampleCount) · Nodes: \(graph.nodes.count) · Edges: \(graph.edges.count) · Live data: \(graph.liveDataAvailable ? "yes" : "no")"
            } else {
                let report = try ApplePerformanceService.analyze(
                    tracePath: tracePath,
                    schema: performanceSchema,
                    maximumRows: 5_000,
                    includeRows: false
                )
                performanceOutput = String(decoding: try encoder.encode(report), as: UTF8.self)
                performanceSummary = "\(report.templateSemantic.domain.rawValue) · Rows: \(report.templateSemantic.eventCount) · Threads: \(report.templateSemantic.uniqueThreadCount) · Processes: \(report.templateSemantic.uniqueProcessCount) · Metrics: \(report.templateSemantic.counts.count)"
                timelinePoints = try ApplePerformanceService.timeline(
                    tracePath: tracePath,
                    schema: performanceSchema,
                    maximumRows: 500
                )
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func diffPerformance() {
        guard !tracePath.isEmpty, !comparisonTracePath.isEmpty else {
            errorMessage = "Enter both trace paths first."
            return
        }
        do {
            let diff = try ApplePerformanceService.diff(
                leftTracePath: tracePath,
                rightTracePath: comparisonTracePath,
                schema: performanceSchema == "swift-concurrency" ? "time-profile" : performanceSchema,
                maximumRows: 5_000
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            performanceDiffOutput = String(decoding: try encoder.encode(diff), as: UTF8.self)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createSession() {
        guard sessionID == nil else {
            errorMessage = "A debugger session is already open."
            return
        }
        isBusy = true
        Task {
            do {
                let summary = try await sessions.create()
                sessionID = summary.sessionID
                debuggerState = .session
                debuggerOutput = "Created session \(summary.sessionID)"
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    func launchTarget() {
        guard let sessionID else {
            errorMessage = "Create a debugger session first."
            return
        }
        guard !targetPath.isEmpty else {
            errorMessage = "Choose an authorized local executable first."
            return
        }
        isBusy = true
        Task {
            do {
                let response = try await sessions.launch(
                    sessionID: sessionID,
                    program: targetPath,
                    arguments: [],
                    stopOnEntry: true
                )
                debuggerOutput = String(describing: response)
                try await refreshSnapshot(sessionID: sessionID, threadID: nil)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    func closeSession() {
        guard let sessionID else { return }
        isBusy = true
        Task {
            _ = await sessions.close(sessionID: sessionID)
            self.sessionID = nil
            debuggerState = .ready
            debuggerThreads = []
            debuggerStack = []
            debuggerRegisters = []
            stopSnapshot = nil
            debuggerThreadID = ""
            debuggerOutput = "Session closed"
            isBusy = false
        }
    }

    func inspectThreads() {
        guard let sessionID else {
            errorMessage = "Create a debugger session first."
            return
        }
        isBusy = true
        Task {
            do {
                let response = try await sessions.threads(sessionID: sessionID)
                debuggerThreads = parseThreads(response)
                debuggerOutput = formatted(response)
                debuggerState = .stopped
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    func snapshot() {
        guard let sessionID else {
            errorMessage = "Create a debugger session first."
            return
        }
        isBusy = true
        Task {
            do {
                try await refreshSnapshot(sessionID: sessionID, threadID: Int(debuggerThreadID))
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    func pause() {
        guard let sessionID else {
            errorMessage = "Create a debugger session first."
            return
        }
        isBusy = true
        Task {
            do {
                debuggerOutput = String(describing: try await sessions.pause(sessionID: sessionID))
                debuggerState = .stopped
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    func continueExecution() {
        guard let sessionID, let threadID = Int(debuggerThreadID) else {
            errorMessage = "Enter a stopped thread ID first."
            return
        }
        isBusy = true
        Task {
            do {
                debuggerOutput = String(describing: try await sessions.continueExecution(sessionID: sessionID, threadID: threadID))
                debuggerState = .running
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    func step(_ kind: DebugStepKind) {
        guard let sessionID, let threadID = Int(debuggerThreadID) else {
            errorMessage = "Enter a stopped thread ID first."
            return
        }
        isBusy = true
        Task {
            do {
                debuggerOutput = String(describing: try await sessions.step(sessionID: sessionID, threadID: threadID, kind: kind, granularity: .instruction))
                debuggerState = .stopped
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    func evaluate() {
        guard let sessionID else {
            errorMessage = "Create a debugger session first."
            return
        }
        Task {
            do {
                let response = try await sessions.evaluate(
                    sessionID: sessionID,
                    expression: debuggerExpression,
                    frameID: nil,
                    context: "repl"
                )
                debuggerOutput = String(describing: response)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refreshSnapshot(sessionID: String, threadID: Int?) async throws {
        let snapshot = try await sessions.stopSnapshot(sessionID: sessionID, threadID: threadID, levels: 20)
        stopSnapshot = snapshot
        debuggerThreads = parseThreads(snapshot.threads)
        debuggerStack = parseStack(snapshot.stackTrace)
        debuggerRegisters = parseRegisters(snapshot.registers)
        if let stoppedThreadID = snapshot.stoppedThreadID {
            debuggerThreadID = String(stoppedThreadID)
        }
        debuggerState = .stopped
        debuggerOutput = formatted(snapshot)
    }

    private func formatted<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value) else { return String(describing: value) }
        return String(decoding: data, as: UTF8.self)
    }

    private func parseThreads(_ message: DAPMessage) -> [WorkbenchThreadRow] {
        guard let body = object(message.body), let values = array(body["threads"]) else { return [] }
        return values.compactMap { value in
            guard let item = object(value), let id = integer(item["id"]), let name = string(item["name"]) else { return nil }
            return WorkbenchThreadRow(id: id, name: name, state: string(item["state"]) ?? string(item["reason"]) ?? "unknown")
        }
    }

    private func parseStack(_ message: DAPMessage?) -> [WorkbenchStackFrameRow] {
        guard let message, let body = object(message.body), let values = array(body["stackFrames"]) else { return [] }
        return values.compactMap { value in
            guard let item = object(value), let id = integer(item["id"]), let name = string(item["name"]) else { return nil }
            let source = object(item["source"])
            let sourceName = string(source?["name"]) ?? string(source?["path"]) ?? "unknown source"
            let line = integer(item["line"]).map(String.init) ?? "?"
            let column = integer(item["column"]).map(String.init) ?? "?"
            let instruction = string(item["instructionPointerReference"]) ?? "unknown address"
            return WorkbenchStackFrameRow(id: id, name: name, location: "\(sourceName):\(line):\(column)", instructionPointer: instruction)
        }
    }

    private func parseRegisters(_ snapshot: RegisterSnapshot?) -> [WorkbenchRegisterRow] {
        guard let variables = snapshot?.variables, let body = object(variables.body), let values = array(body["variables"]) else { return [] }
        return values.compactMap { value in
            guard let item = object(value), let name = string(item["name"]), let value = string(item["value"]) else { return nil }
            return WorkbenchRegisterRow(id: name, name: name, value: value)
        }
    }

    private func object(_ value: DAPValue?) -> [String: DAPValue]? {
        guard let value, case .object(let object) = value else { return nil }
        return object
    }

    private func array(_ value: DAPValue?) -> [DAPValue]? {
        guard let value, case .array(let array) = value else { return nil }
        return array
    }

    private func string(_ value: DAPValue?) -> String? {
        guard let value, case .string(let string) = value else { return nil }
        return string
    }

    private func integer(_ value: DAPValue?) -> Int? {
        guard let value else { return nil }
        switch value {
        case .integer(let integer): return integer
        case .double(let double): return Int(double)
        default: return nil
        }
    }
}
