// Apple Debug MCP Workbench
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppleDebugCore
import SwiftUI
import UniformTypeIdentifiers

struct WorkbenchView: View {
    @StateObject private var model = WorkbenchModel()
    @State private var showingTargetImporter = false
    @State private var showingEvidenceImporter = false

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                List(selection: $model.panel) {
                    ForEach(WorkbenchModel.Panel.allCases) { panel in
                        Label(panel.rawValue, systemImage: icon(for: panel))
                            .tag(panel)
                    }
                }
                .listStyle(.sidebar)

                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Label(model.targetDisplayName, systemImage: model.hasTarget ? "doc.badge.gearshape" : "doc")
                        .lineLimit(1)
                    Text(model.debuggerState.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
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
                case .evidence: EvidencePanel(model: model)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingTargetImporter = true
                } label: {
                    Label("Open Target", systemImage: "folder")
                }

                Button {
                    showingEvidenceImporter = true
                } label: {
                    Label("Open Evidence", systemImage: "checkmark.seal")
                }

                if model.hasTarget, model.sessionID == nil {
                    Button("Clear", role: .destructive) {
                        model.clearTarget()
                    }
                }
            }
            ToolbarItem(placement: .status) {
                Label(model.debuggerState.rawValue, systemImage: statusIcon)
                    .foregroundStyle(statusColor)
            }
        }
        .fileImporter(
            isPresented: $showingTargetImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    model.setTarget(url: url)
                }
            case .failure(let error):
                model.errorMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $showingEvidenceImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    model.setEvidence(url: url)
                }
            case .failure(let error):
                model.errorMessage = error.localizedDescription
            }
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

    private var statusIcon: String {
        switch model.debuggerState {
        case .ready: return "circle"
        case .session: return "circle.dotted"
        case .stopped: return "pause.circle.fill"
        case .running: return "play.circle.fill"
        }
    }

    private var statusColor: Color {
        switch model.debuggerState {
        case .ready: return .secondary
        case .session: return .orange
        case .stopped: return .green
        case .running: return .accentColor
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
        case .evidence: return "checkmark.seal"
        }
    }
}

struct OverviewPanel: View {
    @ObservedObject var model: WorkbenchModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Apple Debug Workbench")
                    .font(.largeTitle.bold())
                Text("A native macOS surface for the Apple Debug MCP analyzers. Select an authorized target, open a policy-gated debugger session, and inspect typed stop evidence.")
                    .foregroundStyle(.secondary)

                GroupBox("Current target") {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: model.hasTarget ? "doc.badge.gearshape" : "doc")
                            .font(.title2)
                            .foregroundStyle(model.hasTarget ? Color.accentColor : Color.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.targetDisplayName)
                                .font(.headline)
                            Text(model.targetSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Spacer()
                        Label(model.debuggerState.rawValue, systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Quick start") {
                    VStack(alignment: .leading, spacing: 8) {
                        quickStartRow("1", "Open Target", "Choose a signed or otherwise authorized local executable from the toolbar.")
                        quickStartRow("2", "Debugger", "Create a session, launch stopped, and inspect the typed stop snapshot.")
                        quickStartRow("3", "Evidence", "Use the raw response disclosure when exact DAP details are needed; all operations remain policy-gated.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Capabilities")
                        .font(.title2.bold())
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

    private func quickStartRow(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(.quaternary, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct AssemblerPanel: View {
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
            ScrollView {
                Text(model.assemblyOutput.isEmpty ? "Assemble a bounded, self-contained snippet." : model.assemblyOutput)
                    .textSelection(.enabled)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct ControlFlowPanel: View {
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

struct ControlFlowGraphView: View {
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

struct PerformancePanel: View {
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

struct BoundaryPanel: View {
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
