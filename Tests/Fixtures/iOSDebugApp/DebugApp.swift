// Apple Debug MCP iOS fixture
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@main
struct DebugApp: App {
    @State private var input = ""
    @State private var status = "Ready"

    init() {
        DispatchQueue.global(qos: .utility).async {
            var value = 0
            while true {
                value = DebugControlProbe.tick(value)
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Text("Apple Debug MCP")
                    .font(.title)
                    .accessibilityIdentifier("debug.fixture.title")
                Text("iOS debugging fixture")
                    .accessibilityIdentifier("debug.fixture.subtitle")
                TextField("Enter text", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("debug.fixture.input")
                Button("Apply") {
                    status = input.isEmpty ? "Ready" : input
                }
                .accessibilityIdentifier("debug.fixture.button")
                Text(status)
                    .accessibilityIdentifier("debug.fixture.status")
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(0..<12, id: \.self) { index in
                            Text("Fixture item \(index)")
                        }
                    }
                }
                .frame(height: 120)
                .accessibilityIdentifier("debug.fixture.scroll")
            }
            .padding()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("debug.fixture.root")
        }
    }
}

private enum DebugControlProbe {
    @inline(never)
    static func tick(_ value: Int) -> Int {
        let next = value &+ 1
        UserDefaults.standard.set(next, forKey: "apple-debug-mcp-control-probe")
        return next
    }
}
