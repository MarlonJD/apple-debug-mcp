// Apple Debug MCP iOS fixture
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@main
struct DebugApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Text("Apple Debug MCP")
                    .font(.title)
                Text("iOS debugging fixture")
            }
            .padding()
        }
    }
}
