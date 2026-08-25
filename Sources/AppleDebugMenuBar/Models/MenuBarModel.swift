// Apple Debug MCP Menu Bar
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Foundation
import SwiftUI

@MainActor
final class MenuBarModel: ObservableObject {
    @Published private(set) var serverState: MCPServerController.State = .stopped
    @Published var launchAtLogin: Bool
    @Published var startServerAtLogin: Bool {
        didSet { UserDefaults.standard.set(startServerAtLogin, forKey: Self.startServerAtLoginKey) }
    }
    @Published var message: String?

    let serverController: MCPServerController
    let loginItemController: LoginItemController

    private static let startServerAtLoginKey = "startMCPServerAtLogin"
    private var didRunStartupAction = false

    init() {
        let serverController = MCPServerController()
        let loginItemController = LoginItemController()
        self.serverController = serverController
        self.loginItemController = loginItemController
        self.launchAtLogin = loginItemController.isEnabled
        self.startServerAtLogin = UserDefaults.standard.object(forKey: Self.startServerAtLoginKey) as? Bool ?? true
        self.message = nil
        serverController.onStateChange = { [weak self] state in
            self?.serverState = state
        }
        loginItemController.onStatusChange = { [weak self] enabled in
            self?.launchAtLogin = enabled
        }
        if startServerAtLogin {
            startServer()
        }
        didRunStartupAction = true
    }

    var menuBarIcon: String {
        switch serverState {
        case .running: return "ladybug.fill"
        case .starting, .stopping: return "ladybug"
        case .failed: return "ladybug.slash"
        case .stopped: return "ladybug"
        }
    }

    var serverStatusTitle: String {
        switch serverState {
        case .running(let processID): return "MCP running · \(processID)"
        case .starting: return "MCP starting…"
        case .stopping: return "MCP stopping…"
        case .failed(let error): return "MCP failed · \(error)"
        case .stopped: return "MCP stopped"
        }
    }

    var canStartServer: Bool {
        switch serverState {
        case .running, .starting: return false
        case .stopping, .stopped, .failed: return true
        }
    }

    var canStopServer: Bool {
        switch serverState {
        case .running, .starting: return true
        case .stopping, .stopped, .failed: return false
        }
    }

    func startIfNeeded() {
        guard !didRunStartupAction else { return }
        didRunStartupAction = true
        guard startServerAtLogin else { return }
        startServer()
    }

    func startServer() {
        do {
            try serverController.start()
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    func stopServer() {
        serverController.stop()
        message = nil
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try loginItemController.setEnabled(enabled)
            launchAtLogin = loginItemController.isEnabled
            message = nil
        } catch {
            launchAtLogin = loginItemController.isEnabled
            message = error.localizedDescription
        }
    }

    func openServerLog() {
        guard NSWorkspace.shared.open(serverController.logURL) else {
            message = "Could not open the MCP server log."
            return
        }
        message = nil
    }

    func quit() {
        serverController.stop()
        NSApplication.shared.terminate(nil)
    }
}
