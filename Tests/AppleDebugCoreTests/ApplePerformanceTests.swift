// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class ApplePerformanceTests: XCTestCase {
    func testAnalysisRejectsUnsupportedSchema() {
        XCTAssertThrowsError(
            try ApplePerformanceService.analyze(
                tracePath: "/tmp/example.trace",
                schema: "arbitrary-shell-schema"
            )
        ) { error in
            XCTAssertEqual(error as? ApplePerformanceError, .invalidRequest)
        }
    }

    func testAnalysisReportsMissingTrace() {
        XCTAssertThrowsError(
            try ApplePerformanceService.analyze(tracePath: "/tmp/example.trace")
        ) { error in
            XCTAssertEqual(error as? ApplePerformanceError, .traceNotFound)
        }
    }

    func testBuildsTemplateSpecificAllocationReport() {
        let row = makeRow(fields: ["allocation-size": "1024", "allocation-count": "1"])

        let report = ApplePerformanceService.buildTemplateSemanticReport(
            templateName: "Allocations",
            schema: "allocations",
            rows: [row]
        )

        XCTAssertEqual(report.domain, .allocations)
        XCTAssertEqual(report.counts["allocations"], 1)
        XCTAssertEqual(report.numericTotals["allocation-size"], 1024)
    }

    func testBuildsTemplateSpecificConcurrencyReportFromPublicFields() {
        let row = makeRow(fields: [
            "swift-task-id": "42",
            "swift-actor-id": "actor-1",
            "swift-task-state": "Continuation",
            "duration": "100"
        ])

        let report = ApplePerformanceService.buildTemplateSemanticReport(
            templateName: "Swift Concurrency",
            schema: "swift-concurrency",
            rows: [row]
        )

        XCTAssertEqual(report.domain, .swiftConcurrency)
        XCTAssertEqual(report.counts["tasks"], 1)
        XCTAssertEqual(report.counts["actors"], 1)
        XCTAssertEqual(report.counts["continuations"], 1)
        XCTAssertEqual(report.durationsNanoseconds["durationNanoseconds"], 100)
    }

    func testMapsRemainingAppleTemplateDomains() {
        let row = makeRow(fields: ["duration": "10", "power-microwatts": "3"])

        XCTAssertEqual(
            ApplePerformanceService.buildTemplateSemanticReport(templateName: "System Trace", schema: "time-profile", rows: [row]).domain,
            .systemTrace
        )
        XCTAssertEqual(
            ApplePerformanceService.buildTemplateSemanticReport(templateName: "Power Profiler", schema: "power", rows: [row]).domain,
            .powerEnergy
        )
        XCTAssertEqual(
            ApplePerformanceService.buildTemplateSemanticReport(templateName: "Animation Hitches", schema: "animation-hitches", rows: [row]).domain,
            .animation
        )
        XCTAssertEqual(
            ApplePerformanceService.buildTemplateSemanticReport(templateName: "Signposts", schema: "os-signpost", rows: [row]).domain,
            .signposts
        )
    }

    private func makeRow(fields: [String: String]) -> ApplePerformanceTraceRow {
        ApplePerformanceTraceRow(
            timeNanoseconds: 1,
            timeFormatted: "1 ns",
            processName: "fixture",
            processID: 1,
            threadName: "worker",
            threadID: 2,
            core: 0,
            state: "Running",
            weightNanoseconds: 1,
            sampleType: "fixture",
            stackSummary: nil,
            addresses: [],
            frames: [],
            fields: fields
        )
    }
}
