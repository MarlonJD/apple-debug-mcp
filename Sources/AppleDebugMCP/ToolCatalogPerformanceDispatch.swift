// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppleDebugCore
import MCP

extension ToolCatalog {
    static func dispatchPerformance(
        _ params: CallTool.Parameters,
        context: Context
    ) async -> CallTool.Result? {
        switch params.name {
        case "apple_performance_record":
            do {
                return result(
                    for: try ApplePerformanceService.record(
                        processID: intValue(from: params.arguments?["processID"]),
                        simulatorUDID: params.arguments?["simulatorUDID"]?.stringValue,
                        coreDeviceIdentifier: params.arguments?["coreDeviceIdentifier"]?.stringValue,
                        template: params.arguments?["template"]?.stringValue ?? "Time Profiler",
                        durationSeconds: intValue(from: params.arguments?["durationSeconds"]) ?? 5,
                        outputPath: params.arguments?["outputPath"]?.stringValue ?? ""
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_performance_analyze":
            guard let tracePath = params.arguments?["tracePath"]?.stringValue else {
                return errorResult("Missing required tracePath argument.")
            }
            do {
                return result(
                    for: try ApplePerformanceService.analyze(
                        tracePath: tracePath,
                        schema: params.arguments?["schema"]?.stringValue ?? "time-profile",
                        maximumRows: intValue(from: params.arguments?["maximumRows"]) ?? 5_000,
                        includeRows: boolValue(
                            from: params.arguments?["includeRows"],
                            default: false
                        )
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_performance_semantic_report":
            guard let tracePath = params.arguments?["tracePath"]?.stringValue else {
                return errorResult("Missing required tracePath argument.")
            }
            do {
                let analysis = try ApplePerformanceService.analyze(
                    tracePath: tracePath,
                    schema: params.arguments?["schema"]?.stringValue ?? "time-profile",
                    maximumRows: intValue(from: params.arguments?["maximumRows"]) ?? 5_000,
                    includeRows: false
                )
                return result(for: analysis.templateSemantic)
            } catch {
                return errorResult(error)
            }
        case "apple_performance_timeline":
            guard let tracePath = params.arguments?["tracePath"]?.stringValue else {
                return errorResult("Missing required tracePath argument.")
            }
            do {
                return result(
                    for: try ApplePerformanceService.timeline(
                        tracePath: tracePath,
                        schema: params.arguments?["schema"]?.stringValue ?? "time-profile",
                        maximumRows: intValue(from: params.arguments?["maximumRows"]) ?? 5_000
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_performance_diff":
            guard let leftTracePath = params.arguments?["leftTracePath"]?.stringValue,
                  let rightTracePath = params.arguments?["rightTracePath"]?.stringValue else {
                return errorResult("Missing required leftTracePath or rightTracePath argument.")
            }
            do {
                return result(
                    for: try ApplePerformanceService.diff(
                        leftTracePath: leftTracePath,
                        rightTracePath: rightTracePath,
                        schema: params.arguments?["schema"]?.stringValue ?? "time-profile",
                        maximumRows: intValue(from: params.arguments?["maximumRows"]) ?? 5_000
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_swift_concurrency_graph":
            guard let tracePath = params.arguments?["tracePath"]?.stringValue else {
                return errorResult("Missing required tracePath argument.")
            }
            do {
                return result(
                    for: try AppleSwiftConcurrencyGraphService.analyze(
                        tracePath: tracePath,
                        maximumRows: intValue(from: params.arguments?["maximumRows"]) ?? 5_000
                    )
                )
            } catch {
                return errorResult(error)
            }
        default:
            return nil
        }
    }
}
