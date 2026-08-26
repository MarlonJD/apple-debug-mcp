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
                        .lineLimit(2)
                }
            }

            Divider()

            if model.canStartServer {
                Button("Start MCP Server") { model.startServer() }
                    .accessibilityIdentifier("menubar.start-server")
            }
            if model.canStopServer {
                Button("Stop MCP Server") { model.stopServer() }
                    .accessibilityIdentifier("menubar.stop-server")
            }
            if case .running = model.serverState {
                Button("Copy MCP Endpoint URL") { model.copyEndpointURL() }
                    .accessibilityIdentifier("menubar.copy-endpoint")
            }
            Button("Open Server Log") { model.openServerLog() }
                .accessibilityIdentifier("menubar.open-server-log")

            Divider()

            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                )
            )
            .accessibilityIdentifier("menubar.launch-at-login")
            Toggle("Start MCP at Login", isOn: $model.startServerAtLogin)
                .accessibilityIdentifier("menubar.start-server-at-login")

            Text(model.loginItemController.statusDescription)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("menubar.login-item-status")

            if model.shouldShowLoginItemSettings {
                Button("Open Login Item Settings") { model.openLoginItemSettings() }
                    .accessibilityIdentifier("menubar.open-login-item-settings")
            }

            if let message = model.message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            Button("Quit") { model.quit() }
                .keyboardShortcut("q")
                .accessibilityIdentifier("menubar.quit")
        }
        .padding(14)
        .frame(width: 280)
        .accessibilityIdentifier("menubar.popover")
    }
}
