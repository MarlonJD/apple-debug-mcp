// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

actor WorkActor {
    private var value = 0

    func increment() async {
        value += 1
        try? await Task.sleep(for: .milliseconds(2))
        value += 1
    }
}

@main
struct SwiftConcurrencyTarget {
    static func main() async {
        let actor = WorkActor()
        for _ in 0..<300 {
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<32 {
                    group.addTask {
                        await actor.increment()
                    }
                }
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        try? await Task.sleep(for: .seconds(30))
        print("swift-concurrency-target-complete")
    }
}
