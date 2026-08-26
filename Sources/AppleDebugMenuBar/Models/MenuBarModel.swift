// Apple Debug MCP Menu Bar
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Foundation
import OSLog
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

    private let logger = Logger(
        subsystem: "com.burakkarahan.apple-debug-menubar",
        category: "MenuBar"
    )
    private static let startServerAtLoginKey = "startMCPServerAtLogin"

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
        logger.info("Menu bar initialized with start-at-login preference: \(self.startServerAtLogin, privacy: .public)")
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
        case .running(let processID, let url): return "MCP running · \(processID) · \(url.absoluteString)"
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

    func startServer() {
        logger.info("MCP server start requested")
        do {
            try serverController.start()
            message = nil
        } catch {
            logger.error("MCP server start failed: \(error.localizedDescription, privacy: .public)")
            message = error.localizedDescription
        }
    }

    func stopServer() {
        logger.info("MCP server stop requested")
        serverController.stop()
        message = nil
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        logger.info("Launch-at-login change requested: \(enabled, privacy: .public)")
        do {
            try loginItemController.setEnabled(enabled)
            launchAtLogin = loginItemController.isEnabled
            logger.info("Launch-at-login status: \(self.loginItemController.statusDescription, privacy: .public)")
            message = nil
        } catch {
            launchAtLogin = loginItemController.isEnabled
            logger.error("Launch-at-login change failed: \(error.localizedDescription, privacy: .public)")
            message = error.localizedDescription
        }
    }

    var shouldShowLoginItemSettings: Bool {
        switch loginItemController.status {
        case .requiresApproval, .notFound: return true
        case .enabled, .notRegistered: return false
        @unknown default: return true
        }
    }

    func openLoginItemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"),
              NSWorkspace.shared.open(url) else {
            message = "Could not open Login Items settings."
            logger.error("Login Items settings could not be opened")
            return
        }
        logger.info("Login Items settings opened")
        message = nil
    }

    func openServerLog() {
        logger.info("Server log open requested")
        guard NSWorkspace.shared.open(serverController.logURL) else {
            logger.error("Server log could not be opened")
            message = "Could not open the MCP server log."
            return
        }
        message = nil
    }

    func copyEndpointURL() {
        logger.info("MCP endpoint copy requested")
        guard case .running(_, let url) = serverState else {
            message = "The MCP daemon endpoint is not available."
            logger.error("MCP endpoint copy rejected because the daemon is not running")
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        message = "MCP endpoint URL copied."
    }

    func quit() {
        logger.info("Menu bar quit requested")
        serverController.stop()
        NSApplication.shared.terminate(nil)
    }
}
