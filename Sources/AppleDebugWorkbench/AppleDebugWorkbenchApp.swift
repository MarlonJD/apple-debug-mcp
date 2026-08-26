// Apple Debug MCP Workbench
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@main
struct AppleDebugWorkbenchApp: App {
    var body: some Scene {
        WindowGroup("Apple Debug Workbench") {
            WorkbenchView()
                .frame(minWidth: 1_080, minHeight: 720)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
