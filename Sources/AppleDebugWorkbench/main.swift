// Apple Debug MCP Workbench
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppleDebugCore
import SwiftUI

@main
struct AppleDebugWorkbenchApp: App {
    var body: some Scene {
        WindowGroup("Apple Debug Workbench") {
            WorkbenchView()
                .frame(minWidth: 980, minHeight: 680)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

@MainActor
private final class WorkbenchModel: ObservableObject {
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
    @Published var sessionID: String?
    @Published var debuggerOutput = ""
    @Published var debuggerThreadID = ""
    @Published var debuggerExpression = ""
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
        Task {
            do {
                let summary = try await sessions.create()
                sessionID = summary.sessionID
                debuggerOutput = "Created session \(summary.sessionID)"
                errorMessage = nil
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func launchTarget() {
        guard let sessionID else { errorMessage = "Create a debugger session first."; return }
        Task {
            do {
                let response = try await sessions.launch(sessionID: sessionID, program: targetPath, arguments: [], stopOnEntry: true)
                debuggerOutput = String(describing: response)
                errorMessage = nil
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func closeSession() {
        guard let sessionID else { return }
        Task {
            _ = await sessions.close(sessionID: sessionID)
            self.sessionID = nil
            debuggerOutput = "Session closed"
        }
    }

    func inspectThreads() {
        guard let sessionID else { errorMessage = "Create a debugger session first."; return }
        Task {
            do {
                let response = try await sessions.threads(sessionID: sessionID)
                debuggerOutput = String(describing: response)
                errorMessage = nil
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func snapshot() {
        guard let sessionID else { errorMessage = "Create a debugger session first."; return }
        let threadID = Int(debuggerThreadID)
        Task {
            do {
                let response = try await sessions.stopSnapshot(sessionID: sessionID, threadID: threadID, levels: 20)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                debuggerOutput = String(decoding: try encoder.encode(response), as: UTF8.self)
                errorMessage = nil
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func pause() {
        guard let sessionID else { errorMessage = "Create a debugger session first."; return }
        Task {
            do {
                debuggerOutput = String(describing: try await sessions.pause(sessionID: sessionID))
                errorMessage = nil
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func continueExecution() {
        guard let sessionID, let threadID = Int(debuggerThreadID) else {
            errorMessage = "Enter a stopped thread ID first."
            return
        }
        Task {
            do {
                debuggerOutput = String(describing: try await sessions.continueExecution(sessionID: sessionID, threadID: threadID))
                errorMessage = nil
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func step(_ kind: DebugStepKind) {
        guard let sessionID, let threadID = Int(debuggerThreadID) else {
            errorMessage = "Enter a stopped thread ID first."
            return
        }
        Task {
            do {
                debuggerOutput = String(describing: try await sessions.step(sessionID: sessionID, threadID: threadID, kind: kind, granularity: .instruction))
                errorMessage = nil
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func evaluate() {
        guard let sessionID else { errorMessage = "Create a debugger session first."; return }
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
            } catch { errorMessage = error.localizedDescription }
        }
    }
}

private struct WorkbenchView: View {
    @StateObject private var model = WorkbenchModel()

    var body: some View {
        NavigationSplitView {
            List(WorkbenchModel.Panel.allCases, selection: $model.panel) { panel in
                Label(panel.rawValue, systemImage: icon(for: panel))
                    .tag(panel)
            }
            .navigationTitle("Apple Debug")
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                switch model.panel {
                case .overview: OverviewPanel(model: model)
                case .debugger: DebuggerPanel(model: model)
                case .assembler: AssemblerPanel(model: model)
                case .controlFlow: ControlFlowPanel(model: model)
                case .performance: PerformancePanel(model: model)
                case .boundaries: BoundaryPanel(model: model)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .alert("Workbench error", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Unknown error")
        }
    }

    private func icon(for panel: WorkbenchModel.Panel) -> String {
        switch panel {
        case .overview: return "square.grid.2x2"
        case .debugger: return "ladybug"
        case .assembler: return "chevron.left.forwardslash.chevron.right"
        case .controlFlow: return "point.3.connected.trianglepath.dotted"
        case .performance: return "waveform.path.ecg"
        case .boundaries: return "shield.lefthalf.filled"
        }
    }
}

private struct DebuggerPanel: View {
    @ObservedObject var model: WorkbenchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("LLDB-DAP Debugger").font(.title.bold())
            Text("Session control is backed by the same policy-gated DebugSessionManager as the MCP server. Expression evaluation still requires its separate explicit grant.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Create session") { model.createSession() }
                Button("Launch stopped target") { model.launchTarget() }
                .disabled(model.sessionID == nil)
                Button("Threads") { model.inspectThreads() }
                    .disabled(model.sessionID == nil)
                Button("Stop snapshot") { model.snapshot() }
                    .disabled(model.sessionID == nil)
                Button("Pause") { model.pause() }
                    .disabled(model.sessionID == nil)
                Button("Continue") { model.continueExecution() }
                    .disabled(model.sessionID == nil)
                Button("Close") { model.closeSession() }
                    .disabled(model.sessionID == nil)
            }
            HStack {
                Button("Step in") { model.step(.inInstruction) }
                Button("Step over") { model.step(.over) }
                Button("Step out") { model.step(.out) }
            }
            .disabled(model.sessionID == nil)
            TextField("Absolute signed target path", text: $model.targetPath)
                .textFieldStyle(.roundedBorder)
            TextField("Optional thread ID for snapshot", text: $model.debuggerThreadID)
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("Authorized LLDB expression", text: $model.debuggerExpression)
                    .textFieldStyle(.roundedBorder)
                Button("Evaluate") { model.evaluate() }
                    .disabled(model.sessionID == nil || model.debuggerExpression.isEmpty)
            }
            if let sessionID = model.sessionID {
                Label("Session: \(sessionID)", systemImage: "circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
            ScrollView {
                Text(model.debuggerOutput.isEmpty ? "No debugger response yet." : model.debuggerOutput)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct OverviewPanel: View {
    @ObservedObject var model: WorkbenchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Apple Debug Workbench").font(.largeTitle.bold())
            Text("Native macOS surface for the Apple Debug MCP analyzers. Debug sessions, Simulator controls, and external plugin code remain capability-gated.")
                .foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(model.capabilities, id: \.platform) { report in
                        GroupBox(report.platform.rawValue) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Supported: \(report.supported.map(\.rawValue).joined(separator: ", "))")
                                    .font(.caption)
                                if !report.restricted.isEmpty {
                                    Text("Restricted: \(report.restricted.map(\.rawValue).joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }
}

private struct AssemblerPanel: View {
    @ObservedObject var model: WorkbenchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Assembler").font(.title.bold())
            HStack {
                Picker("Architecture", selection: $model.architecture) {
                    Text("arm64").tag("arm64")
                    Text("x86_64").tag("x86_64")
                }
                .frame(width: 160)
                Button("Assemble") { model.assemble() }
            }
            TextEditor(text: $model.assemblySource)
                .font(.system(.body, design: .monospaced))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
            Text("Output").font(.headline)
            ScrollView { Text(model.assemblyOutput.isEmpty ? "Assemble a bounded, self-contained snippet." : model.assemblyOutput).textSelection(.enabled).font(.system(.body, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading) }
                .padding(10)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct ControlFlowPanel: View {
    @ObservedObject var model: WorkbenchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Control Flow / Call Graph").font(.title.bold())
            HStack {
                TextField("Absolute Mach-O path", text: $model.analysisPath)
                    .textFieldStyle(.roundedBorder)
                Button("Analyze") { model.analyzeControlFlow() }
            }
            if !model.controlFlowSummary.isEmpty {
                Text(model.controlFlowSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !model.controlFlowFunctions.isEmpty {
                if let function = model.controlFlowFunctions.first {
                    GroupBox("CFG graph · \(function.name)") {
                        ControlFlowGraphView(function: function)
                            .frame(height: min(420, CGFloat(max(1, function.blocks.count)) * 72))
                    }
                }
                GroupBox("Call graph / pseudo-code") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(model.controlFlowFunctions.prefix(32), id: \.name) { function in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(function.name)
                                        .font(.system(.body, design: .monospaced).bold())
                                    Text(function.callees.isEmpty ? "no direct callees" : "→ " + function.callees.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(function.pseudoCode)
                                        .font(.system(.caption2, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                                Divider()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 220)
                }
            }
            TextEditor(text: $model.controlFlowOutput)
                .font(.system(.body, design: .monospaced))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        }
    }
}

private struct ControlFlowGraphView: View {
    let function: ControlFlowFunction

    var body: some View {
        let blocks = function.blocks
        let positions = Dictionary(uniqueKeysWithValues: blocks.enumerated().map { index, block in
            (block.startAddress, CGPoint(x: 150, y: CGFloat(index) * 72 + 28))
        })
        ScrollView(.vertical) {
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for block in blocks {
                        guard let source = positions[block.startAddress] else { continue }
                        for successor in block.successors {
                            guard let target = positions[successor] else { continue }
                            var path = Path()
                            path.move(to: CGPoint(x: source.x, y: source.y + 22))
                            path.addLine(to: CGPoint(x: target.x, y: target.y - 22))
                            context.stroke(path, with: .color(.accentColor.opacity(0.7)), lineWidth: 2)
                        }
                    }
                }
                .frame(width: 320, height: CGFloat(max(1, blocks.count)) * 72)
                ForEach(blocks, id: \.startAddress) { block in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(block.startAddress) – \(block.endAddress)")
                            .font(.system(.caption, design: .monospaced).bold())
                        Text("\(block.instructionCount) instructions")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if !block.successors.isEmpty {
                            Text("→ \(block.successors.joined(separator: ", "))")
                                .font(.system(.caption2, design: .monospaced))
                                .lineLimit(1)
                        }
                    }
                    .padding(6)
                    .frame(width: 260, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.accentColor.opacity(0.45)))
                    .position(positions[block.startAddress] ?? CGPoint(x: 150, y: 28))
                }
            }
            .frame(width: 320, height: CGFloat(max(1, blocks.count)) * 72)
        }
    }
}

private struct PerformancePanel: View {
    @ObservedObject var model: WorkbenchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Performance / Concurrency").font(.title.bold())
            Text("Analyze an existing .trace bundle through the same bounded public xctrace parsers exposed by MCP.")
                .foregroundStyle(.secondary)
            HStack {
                TextField("Absolute .trace bundle path", text: $model.tracePath)
                    .textFieldStyle(.roundedBorder)
                Picker("Schema", selection: $model.performanceSchema) {
                    Text("Time Profiler").tag("time-profile")
                    Text("Swift Concurrency Graph").tag("swift-concurrency")
                    Text("Allocations").tag("allocations")
                    Text("OS Signposts").tag("os-signpost")
                    Text("Animation Hitches").tag("animation-hitches")
                    Text("Power / Energy").tag("power")
                }
                .frame(width: 190)
                Button("Analyze") { model.analyzePerformance() }
                    .disabled(model.tracePath.isEmpty)
            }
            HStack {
                TextField("Comparison .trace (optional)", text: $model.comparisonTracePath)
                    .textFieldStyle(.roundedBorder)
                Button("Diff") { model.diffPerformance() }
                    .disabled(model.tracePath.isEmpty || model.comparisonTracePath.isEmpty)
            }
            if !model.performanceSummary.isEmpty {
                Text(model.performanceSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !model.timelinePoints.isEmpty {
                GroupBox("Timeline") {
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 8) {
                            ForEach(model.timelinePoints.prefix(80), id: \.index) { point in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(point.label)
                                        .font(.caption.bold())
                                        .lineLimit(2)
                                    Text("\(point.timeNanoseconds) ns")
                                        .font(.caption2.monospaced())
                                    if let state = point.state {
                                        Text(state).font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                .padding(6)
                                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
                                .frame(width: 130, alignment: .leading)
                            }
                        }
                    }
                }
            }
            ScrollView {
                Text(model.performanceOutput.isEmpty ? "Select an existing trace bundle and schema." : model.performanceOutput)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            if !model.performanceDiffOutput.isEmpty {
                GroupBox("Trace diff") {
                    ScrollView {
                        Text(model.performanceDiffOutput)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 180)
                }
            }
        }
    }
}

private struct BoundaryPanel: View {
    @ObservedObject var model: WorkbenchModel

    var body: some View {
        let reverse = ReverseExecutionService.capabilities()
        let kernel = AppleKernelCapabilityService.report()
        return VStack(alignment: .leading, spacing: 14) {
            Text("Platform Boundaries").font(.title.bold())
            GroupBox("Reverse execution") {
                Text(reverse.notes.joined(separator: "\n\n"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox("Kernel debugging") {
                Text(kernel.notes.joined(separator: "\n\n"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer()
        }
    }
}
