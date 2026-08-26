// Apple Debug MCP Workbench
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppleDebugCore
import SwiftUI

struct DebuggerPanel: View {
    @ObservedObject var model: WorkbenchModel
    @State private var showingRawResponse = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("LLDB-DAP Debugger")
                    .font(.title.bold())
                Text("The Workbench uses the same policy-gated DebugSessionManager as the MCP server. Launch, evaluate, and memory writes stay explicit and target-scoped.")
                    .foregroundStyle(.secondary)

                GroupBox("Target") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: model.hasTarget ? "doc.badge.gearshape" : "doc")
                                .foregroundStyle(model.hasTarget ? Color.accentColor : Color.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.targetDisplayName)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(model.targetSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            Spacer()
                        }
                        TextField("Absolute signed target path", text: $model.targetPath)
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Session") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label(model.debuggerState.rawValue, systemImage: "circle.fill")
                                .foregroundStyle(stateColor)
                            if let sessionID = model.sessionID {
                                Text("Session \(sessionID)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            Spacer()
                            if model.isBusy {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }

                        HStack {
                            Button("Create session") { model.createSession() }
                                .disabled(model.sessionID != nil || model.isBusy)
                            Button("Launch stopped target") { model.launchTarget() }
                                .disabled(model.sessionID == nil || !model.hasTarget || model.isBusy)
                            Button("Close") { model.closeSession() }
                                .disabled(model.sessionID == nil || model.isBusy)
                        }
                        HStack {
                            Button("Threads") { model.inspectThreads() }
                            Button("Stop snapshot") { model.snapshot() }
                            Button("Pause") { model.pause() }
                            Button("Continue") { model.continueExecution() }
                        }
                        .disabled(model.sessionID == nil || model.isBusy)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Button("Step in") { model.step(.inInstruction) }
                    Button("Step over") { model.step(.over) }
                    Button("Step out") { model.step(.out) }
                    Spacer()
                    TextField("Stopped thread ID", text: $model.debuggerThreadID)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
                .disabled(model.sessionID == nil || model.isBusy)

                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Authorized LLDB expression", text: $model.debuggerExpression)
                        .textFieldStyle(.roundedBorder)
                    Button("Evaluate") { model.evaluate() }
                        .disabled(model.sessionID == nil || model.debuggerExpression.isEmpty || model.isBusy)
                }

                if let snapshot = model.stopSnapshot {
                    StopEvidenceView(snapshot: snapshot)
                }

                if !model.debuggerThreads.isEmpty {
                    GroupBox("Threads") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(model.debuggerThreads) { thread in
                                let isSelected = model.debuggerThreadID == String(thread.id)
                                Button {
                                    model.debuggerThreadID = String(thread.id)
                                } label: {
                                    HStack {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                                        Text("#\(thread.id)")
                                            .font(.system(.body, design: .monospaced).bold())
                                        Text(thread.name)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(thread.state)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !model.debuggerStack.isEmpty {
                    GroupBox("Call stack") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(model.debuggerStack) { frame in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(frame.name)
                                        .font(.system(.body, design: .monospaced).bold())
                                    Text(frame.location)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(frame.instructionPointer)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                if frame.id != model.debuggerStack.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !model.debuggerRegisters.isEmpty {
                    GroupBox("Registers") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), alignment: .leading)], alignment: .leading, spacing: 6) {
                            ForEach(model.debuggerRegisters) { register in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(register.name)
                                        .font(.system(.caption, design: .monospaced).bold())
                                    Text(register.value)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }
                }

                DisclosureGroup("Raw DAP response", isExpanded: $showingRawResponse) {
                    ScrollView {
                        Text(model.debuggerOutput.isEmpty ? "No debugger response yet." : model.debuggerOutput)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 120, maxHeight: 280)
                    .padding(8)
                    .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var stateColor: Color {
        switch model.debuggerState {
        case .ready: return .secondary
        case .session: return .orange
        case .stopped: return .green
        case .running: return .accentColor
        }
    }
}

private struct StopEvidenceView: View {
    let snapshot: DebugStopSnapshot

    var body: some View {
        GroupBox("Stop evidence") {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), alignment: .leading)], alignment: .leading, spacing: 8) {
                    metric("Threads", value: threadCount)
                    metric("Stack frames", value: stackCount)
                    metric("Registers", value: registerCount)
                    metric("Modules", value: moduleCount)
                    metric("Events", value: snapshot.events.count)
                }
                HStack(spacing: 14) {
                    Text("Reason: \(snapshot.stopReason ?? "unknown")")
                    if let threadID = snapshot.stoppedThreadID {
                        Text("Thread: \(threadID)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var threadCount: Int { count(in: snapshot.threads.body, key: "threads") }
    private var stackCount: Int { snapshot.stackTrace.map { count(in: $0.body, key: "stackFrames") } ?? 0 }
    private var registerCount: Int { snapshot.registers?.variables.map { count(in: $0.body, key: "variables") } ?? 0 }
    private var moduleCount: Int { snapshot.modules.map { count(in: $0.body, key: "modules") } ?? 0 }

    private func metric(_ label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func count(in value: DAPValue?, key: String) -> Int {
        guard case .object(let object) = value,
              case .array(let values) = object[key] else { return 0 }
        return values.count
    }
}
