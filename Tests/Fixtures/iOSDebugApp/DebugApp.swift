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
                    .accessibilityIdentifier("debug.fixture.title")
                Text("iOS debugging fixture")
                    .accessibilityIdentifier("debug.fixture.subtitle")
            }
            .padding()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("debug.fixture.root")
        }
    }
}
