// Apple Debug MCP Menu Bar
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

@MainActor
final class MenuBarAppDelegate: NSObject, NSApplicationDelegate {
    weak var serverController: MCPServerController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        serverController?.stopImmediatelyForTermination()
    }
}

@main
struct AppleDebugMenuBarApp: App {
    @NSApplicationDelegateAdaptor(MenuBarAppDelegate.self) private var appDelegate
    @StateObject private var model: MenuBarModel

    init() {
        let model = MenuBarModel()
        _model = StateObject(wrappedValue: model)
        appDelegate.serverController = model.serverController
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(model: model)
        } label: {
            Image(systemName: model.menuBarIcon)
                .symbolRenderingMode(.hierarchical)
                .accessibilityLabel("Apple Debug MCP")
                .accessibilityValue(model.serverStatusTitle)
        }
        .menuBarExtraStyle(.window)
    }
}
