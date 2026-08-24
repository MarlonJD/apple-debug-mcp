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
        case assembler = "Assembler"
        case controlFlow = "Control Flow"
        case boundaries = "Boundaries"
        var id: String { rawValue }
    }

    @Published var panel: Panel = .overview
    @Published var architecture = "arm64"
    @Published var assemblySource = "mov x0, x0\nret\n"
    @Published var assemblyOutput = ""
    @Published var analysisPath = ""
    @Published var controlFlowOutput = ""
    @Published var errorMessage: String?

    let capabilities = CapabilityMatrix.reports()

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
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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
                case .assembler: AssemblerPanel(model: model)
                case .controlFlow: ControlFlowPanel(model: model)
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
        case .assembler: return "chevron.left.forwardslash.chevron.right"
        case .controlFlow: return "point.3.connected.trianglepath.dotted"
        case .boundaries: return "shield.lefthalf.filled"
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
            TextEditor(text: $model.controlFlowOutput)
                .font(.system(.body, design: .monospaced))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
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
