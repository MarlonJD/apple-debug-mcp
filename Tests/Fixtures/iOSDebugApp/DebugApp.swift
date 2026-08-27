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
#if APPLE_DEBUG_VISUAL_CASE
                visualRegressionCard
#endif
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

#if APPLE_DEBUG_VISUAL_CASE
    private var visualRegressionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Transfer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "clock")
                    .accessibilityHidden(true)
            }
            Text("Order\nready")
                .font(.headline)
#if APPLE_DEBUG_VISUAL_FIXED
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
#else
                // Intentional visual bug: the title is forced into one clipped line
                // when the Simulator uses an accessibility content size.
                .lineLimit(1)
#endif
                .accessibilityIdentifier("debug.fixture.visual.title")
#if APPLE_DEBUG_VISUAL_FIXED
            Text("FIXED")
                .foregroundStyle(.green)
                .font(.caption)
                .lineLimit(1)
                .accessibilityIdentifier("debug.fixture.visual.status")
#else
            Text("BUGGY")
                .foregroundStyle(.red)
                .font(.caption)
                .lineLimit(1)
                .accessibilityIdentifier("debug.fixture.visual.status")
#endif
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
#if APPLE_DEBUG_VISUAL_FIXED
        .frame(minHeight: 260, alignment: .leading)
#else
        .frame(height: 52, alignment: .leading)
        .clipped()
#endif
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("debug.fixture.visual.card")
    }
#endif
}

private enum DebugControlProbe {
    @inline(never)
    static func tick(_ value: Int) -> Int {
        let next = value &+ 1
        UserDefaults.standard.set(next, forKey: "apple-debug-mcp-control-probe")
        return next
    }
}
