// Apple Debug MCP Menu Bar
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var model: MenuBarModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: model.menuBarIcon)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Debug MCP")
                        .font(.headline)
                    Text(model.serverStatusTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Divider()

            if model.canStartServer {
                Button("Start MCP Server") { model.startServer() }
            }
            if model.canStopServer {
                Button("Stop MCP Server") { model.stopServer() }
            }
            Button("Open Server Log") { model.openServerLog() }

            Divider()

            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                )
            )
            Toggle("Start MCP at Login", isOn: $model.startServerAtLogin)

            Text(model.loginItemController.statusDescription)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let message = model.message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            Button("Quit") { model.quit() }
                .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 280)
    }
}
