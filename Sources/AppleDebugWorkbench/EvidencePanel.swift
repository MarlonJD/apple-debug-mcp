// Apple Debug MCP Workbench
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct EvidencePanel: View {
    @ObservedObject var model: WorkbenchModel
    @State private var showingRawManifest = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Workflow Evidence")
                    .font(.title.bold())
                Text("Load a bounded JSON manifest from the local MCP debugger workflow to review its steps, policy probes, and cleanup result.")
                    .foregroundStyle(.secondary)

                GroupBox("Manifest") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Absolute evidence manifest path", text: $model.evidencePath)
                                .textFieldStyle(.roundedBorder)
                            Button("Load") { model.loadEvidence() }
                                .disabled(model.evidencePath.isEmpty)
                            if model.evidenceManifest != nil {
                                Button("Clear", role: .destructive) { model.clearEvidence() }
                            }
                        }
                        Text(model.evidencePath.isEmpty ? "Run make mcp-mac-debug-workflow-smoke first, then choose its .build/evidence manifest." : model.evidencePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let manifest = model.evidenceManifest {
                    EvidenceSummaryView(manifest: manifest)

                    GroupBox("Workflow steps") {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(manifest.steps) { step in
                                EvidenceStepRow(step: step)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let probes = manifest.extendedProbes {
                        GroupBox("Policy and failure probes") {
                            VStack(alignment: .leading, spacing: 8) {
                                if let policy = probes.policy {
                                    EvidenceProbeRow(title: "Target launch policy", probe: policy, detail: policy.sessionClosed == true ? "session closed" : nil)
                                }
                                if let cleanup = probes.failedLaunchCleanup {
                                    EvidenceProbeRow(title: "Failed launch cleanup", probe: cleanup, detail: cleanup.sessionRemoved == true ? "session removed" : nil)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    GroupBox("MCP calls (\(manifest.toolCalls.count))") {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(manifest.toolCalls.enumerated()), id: \.offset) { _, call in
                                    HStack(spacing: 8) {
                                        Image(systemName: call.status == "passed" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(call.status == "passed" ? Color.green : Color.red)
                                        Text(call.name)
                                            .font(.system(.caption, design: .monospaced))
                                        Spacer()
                                        Text(call.status)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 220)
                    }

                    DisclosureGroup("Raw manifest", isExpanded: $showingRawManifest) {
                        ScrollView {
                            Text(model.evidenceRawJSON)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 120, maxHeight: 280)
                        .padding(8)
                        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No evidence loaded")
                            .font(.headline)
                        Text("The Workbench can inspect the bounded manifest produced by the local MCP workflow.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                }
            }
        }
    }
}

private struct EvidenceSummaryView: View {
    let manifest: WorkbenchEvidenceManifest

    var body: some View {
        GroupBox("Summary") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(manifest.status.capitalized, systemImage: statusIcon)
                        .foregroundStyle(statusColor)
                        .font(.headline)
                    Spacer()
                    Text(manifest.createdAt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(manifest.workflow) · \(manifest.transport) · schema \(manifest.schemaVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(manifest.target.fixturePath ?? manifest.target.kind)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), alignment: .leading)], alignment: .leading, spacing: 8) {
                    metric("Steps", manifest.steps.count)
                    metric("MCP calls", manifest.toolCalls.count)
                    metric("Architecture", manifest.target.architecture ?? "unknown")
                    metric("Session closed", manifest.cleanup.sessionClosed ? "yes" : "no")
                    metric("Server exited", manifest.cleanup.serverExited ? "yes" : "no")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statusIcon: String {
        manifest.status == "passed" ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
    }

    private var statusColor: Color {
        manifest.status == "passed" ? .green : .orange
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func metric(_ label: String, _ value: Int) -> some View {
        metric(label, String(value))
    }
}

private struct EvidenceStepRow: View {
    let step: WorkbenchEvidenceStep

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: step.status == "passed" ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(step.status == "passed" ? Color.green : Color.red)
            Text(step.name.replacingOccurrences(of: "_", with: " ").capitalized)
            Spacer()
            Text(step.status)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct EvidenceProbeRow: View {
    let title: String
    let probe: WorkbenchEvidenceProbe
    let detail: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: probe.status == "passed" ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(probe.status == "passed" ? Color.green : Color.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(probe.status).font(.caption).foregroundStyle(.secondary)
        }
    }
}
