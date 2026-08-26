// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppleDebugCore
import MCP

extension ToolCatalog {
    static func dispatchSimulator(
        _ params: CallTool.Parameters,
        context: Context
    ) async -> CallTool.Result? {
        switch params.name {
        case "apple_simulator_list":
            do {
                return result(for: try SimulatorService.list())
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_boot", "apple_simulator_shutdown":
            guard let udid = params.arguments?["udid"]?.stringValue else {
                return errorResult("Missing required udid argument.")
            }
            do {
                let action = params.name == "apple_simulator_boot"
                    ? try SimulatorService.boot(udid: udid)
                    : try SimulatorService.shutdown(udid: udid)
                return result(for: action)
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_install":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let appPath = params.arguments?["appPath"]?.stringValue else {
                return errorResult("Missing required udid or appPath argument.")
            }
            do {
                return result(for: try SimulatorService.install(udid: udid, appPath: appPath))
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_launch", "apple_simulator_terminate":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let bundleID = params.arguments?["bundleID"]?.stringValue else {
                return errorResult("Missing required udid or bundleID argument.")
            }
            do {
                let action: SimulatorActionResult
                if params.name == "apple_simulator_launch" {
                    action = try SimulatorService.launch(
                        udid: udid,
                        bundleID: bundleID,
                        arguments: stringArray(from: params.arguments?["arguments"]),
                        terminateRunning: boolValue(
                            from: params.arguments?["terminateRunning"],
                            default: false
                        ),
                        waitForDebugger: boolValue(
                            from: params.arguments?["waitForDebugger"],
                            default: false
                        )
                    )
                } else {
                    action = try SimulatorService.terminate(udid: udid, bundleID: bundleID)
                }
                return result(for: action)
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_screenshot":
            guard let udid = params.arguments?["udid"]?.stringValue else {
                return errorResult("Missing required udid argument.")
            }
            do {
                return result(
                    for: try SimulatorService.screenshot(
                        udid: udid,
                        path: params.arguments?["path"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_open_url":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let url = params.arguments?["url"]?.stringValue else {
                return errorResult("Missing required udid or url argument.")
            }
            do {
                return result(for: try SimulatorService.openURL(udid: udid, url: url))
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_set_location":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let latitude = doubleValue(from: params.arguments?["latitude"]),
                  let longitude = doubleValue(from: params.arguments?["longitude"]) else {
                return errorResult("Missing required udid, latitude, or longitude argument.")
            }
            do {
                return result(
                    for: try SimulatorService.setLocation(
                        udid: udid,
                        latitude: latitude,
                        longitude: longitude
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_clear_location":
            guard let udid = params.arguments?["udid"]?.stringValue else {
                return errorResult("Missing required udid argument.")
            }
            do {
                return result(for: try SimulatorService.clearLocation(udid: udid))
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_record_video":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let path = params.arguments?["path"]?.stringValue else {
                return errorResult("Missing required udid or path argument.")
            }
            do {
                return result(
                    for: try SimulatorService.recordVideo(
                        udid: udid,
                        path: path,
                        durationSeconds: intValue(from: params.arguments?["durationSeconds"]) ?? 1,
                        codec: params.arguments?["codec"]?.stringValue ?? "hevc",
                        display: params.arguments?["display"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_app_info":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let bundleID = params.arguments?["bundleID"]?.stringValue else {
                return errorResult("Missing required udid or bundleID argument.")
            }
            do {
                return result(for: try SimulatorService.appInfo(udid: udid, bundleID: bundleID))
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_get_app_container":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let bundleID = params.arguments?["bundleID"]?.stringValue else {
                return errorResult("Missing required udid or bundleID argument.")
            }
            do {
                return result(
                    for: try SimulatorService.appContainer(
                        udid: udid,
                        bundleID: bundleID,
                        container: params.arguments?["container"]?.stringValue ?? "app"
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_environment":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let operation = params.arguments?["operation"]?.stringValue else {
                return errorResult("Missing required udid or operation argument.")
            }
            do {
                return result(
                    for: try AppleSimulatorEnvironmentService.perform(
                        udid: udid,
                        operation: operation,
                        bundleID: params.arguments?["bundleID"]?.stringValue,
                        service: params.arguments?["service"]?.stringValue,
                        value: params.arguments?["value"]?.stringValue,
                        payload: params.arguments?["payload"].flatMap(dapValue(from:)),
                        variable: params.arguments?["variable"]?.stringValue,
                        mediaPaths: stringArray(from: params.arguments?["mediaPaths"]),
                        statusOverrides: stringDictionary(from: params.arguments?["statusOverrides"])
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_repro_bundle":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let bundleID = params.arguments?["bundleID"]?.stringValue,
                  let outputDirectory = params.arguments?["outputDirectory"]?.stringValue else {
                return errorResult("Missing required udid, bundleID, or outputDirectory argument.")
            }
            do {
                return result(
                    for: try AppleReproBundleService.capture(
                        udid: udid,
                        bundleID: bundleID,
                        outputDirectory: outputDirectory,
                        includeScreenshot: boolValue(from: params.arguments?["includeScreenshot"], default: true),
                        includeAppInfo: boolValue(from: params.arguments?["includeAppInfo"], default: true),
                        includeLogs: boolValue(from: params.arguments?["includeLogs"], default: true),
                        tracePaths: stringArray(from: params.arguments?["tracePaths"]),
                        crashPath: params.arguments?["crashPath"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_ui_snapshot":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let bundleID = params.arguments?["bundleID"]?.stringValue,
                  let projectPath = params.arguments?["projectPath"]?.stringValue,
                  let scheme = params.arguments?["scheme"]?.stringValue else {
                return errorResult("Missing required udid, bundleID, projectPath, or scheme argument.")
            }
            do {
                return result(
                    for: try SimulatorUIService.snapshot(
                        udid: udid,
                        bundleID: bundleID,
                        projectPath: projectPath,
                        scheme: scheme,
                        configuration: params.arguments?["configuration"]?.stringValue ?? "Debug"
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_ui_action":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let bundleID = params.arguments?["bundleID"]?.stringValue,
                  let projectPath = params.arguments?["projectPath"]?.stringValue,
                  let scheme = params.arguments?["scheme"]?.stringValue,
                  let action = params.arguments?["action"]?.stringValue else {
                return errorResult("Missing required udid, bundleID, projectPath, scheme, or action argument.")
            }
            do {
                return result(
                    for: try SimulatorUIService.performAction(
                        udid: udid,
                        bundleID: bundleID,
                        projectPath: projectPath,
                        scheme: scheme,
                        configuration: params.arguments?["configuration"]?.stringValue ?? "Debug",
                        action: .init(
                            action: action,
                            identifier: params.arguments?["identifier"]?.stringValue,
                            text: params.arguments?["text"]?.stringValue,
                            direction: params.arguments?["direction"]?.stringValue,
                            durationSeconds: doubleValue(from: params.arguments?["durationSeconds"]),
                            scale: doubleValue(from: params.arguments?["scale"]),
                            velocity: doubleValue(from: params.arguments?["velocity"]),
                            x: doubleValue(from: params.arguments?["x"]),
                            y: doubleValue(from: params.arguments?["y"]),
                            endX: doubleValue(from: params.arguments?["endX"]),
                            endY: doubleValue(from: params.arguments?["endY"])
                        )
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_ui_probe":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let bundleID = params.arguments?["bundleID"]?.stringValue else {
                return errorResult("Missing required udid or bundleID argument.")
            }
            do {
                return result(
                    for: try SimulatorUIService.installedAppSnapshot(
                        udid: udid,
                        bundleID: bundleID,
                        configuration: params.arguments?["configuration"]?.stringValue ?? "Debug"
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_ui_probe_action":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let bundleID = params.arguments?["bundleID"]?.stringValue,
                  let action = params.arguments?["action"]?.stringValue else {
                return errorResult("Missing required udid, bundleID, or action argument.")
            }
            do {
                return result(
                    for: try SimulatorUIService.performInstalledAppAction(
                        udid: udid,
                        bundleID: bundleID,
                        configuration: params.arguments?["configuration"]?.stringValue ?? "Debug",
                        action: .init(
                            action: action,
                            identifier: params.arguments?["identifier"]?.stringValue,
                            text: params.arguments?["text"]?.stringValue,
                            direction: params.arguments?["direction"]?.stringValue,
                            durationSeconds: doubleValue(from: params.arguments?["durationSeconds"]),
                            scale: doubleValue(from: params.arguments?["scale"]),
                            velocity: doubleValue(from: params.arguments?["velocity"]),
                            x: doubleValue(from: params.arguments?["x"]),
                            y: doubleValue(from: params.arguments?["y"]),
                            endX: doubleValue(from: params.arguments?["endX"]),
                            endY: doubleValue(from: params.arguments?["endY"])
                        )
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
