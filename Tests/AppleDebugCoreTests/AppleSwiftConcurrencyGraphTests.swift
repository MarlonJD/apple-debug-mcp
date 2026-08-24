// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleSwiftConcurrencyGraphTests: XCTestCase {
    func testBuildsTaskActorAndContinuationGraphFromPublicFields() {
        let row = ApplePerformanceTraceRow(
            timeNanoseconds: 1,
            timeFormatted: "1 ns",
            processName: "fixture",
            processID: 42,
            threadName: "worker",
            threadID: 7,
            core: 1,
            state: "running",
            weightNanoseconds: 1,
            sampleType: "Swift Concurrency",
            stackSummary: nil,
            addresses: [],
            frames: [],
            fields: [
                "task": "task-1",
                "actor": "main-actor",
                "continuation": "continuation-1"
            ]
        )

        let graph = AppleSwiftConcurrencyGraphService.build(tracePath: "/tmp/example.trace", rows: [row, row])

        XCTAssertTrue(graph.liveDataAvailable)
        XCTAssertEqual(graph.sampleCount, 2)
        XCTAssertEqual(graph.nodes.map(\.id), ["actor:main-actor", "continuation:continuation-1", "task:task-1"])
        XCTAssertTrue(graph.nodes.allSatisfy { $0.eventCount == 2 })
        XCTAssertEqual(
            graph.edges,
            [
                SwiftConcurrencyEdge(from: "actor:main-actor", to: "task:task-1", kind: "executes"),
                SwiftConcurrencyEdge(from: "task:task-1", to: "continuation:continuation-1", kind: "awaits")
            ]
        )
    }

    func testEmptyRowsRemainExplicitlyUnavailable() {
        let graph = AppleSwiftConcurrencyGraphService.build(tracePath: "/tmp/empty.trace", rows: [])

        XCTAssertFalse(graph.liveDataAvailable)
        XCTAssertEqual(graph.sampleCount, 0)
        XCTAssertTrue(graph.nodes.isEmpty)
        XCTAssertTrue(graph.edges.isEmpty)
        XCTAssertFalse(graph.notes.isEmpty)
    }
}
