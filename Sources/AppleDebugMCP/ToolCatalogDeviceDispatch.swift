// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppleDebugCore
import MCP

extension ToolCatalog {
    static func dispatchDevice(
        _ params: CallTool.Parameters,
        context: Context
    ) async -> CallTool.Result? {
        switch params.name {
        case "apple_device_list":
            do {
                return result(for: try AppleDeviceService.list())
            } catch {
                return errorResult(error)
            }
        case "apple_device_install":
            guard let identifier = params.arguments?["identifier"]?.stringValue,
                  let appPath = params.arguments?["appPath"]?.stringValue else {
                return errorResult("Missing required identifier or appPath argument.")
            }
            do {
                return result(for: try AppleDeviceService.install(identifier: identifier, appPath: appPath))
            } catch {
                return errorResult(error)
            }
        case "apple_device_launch":
            guard let identifier = params.arguments?["identifier"]?.stringValue,
                  let bundleID = params.arguments?["bundleID"]?.stringValue else {
                return errorResult("Missing required identifier or bundleID argument.")
            }
            do {
                return result(
                    for: try AppleDeviceService.launch(
                        identifier: identifier,
                        bundleID: bundleID,
                        startStopped: boolValue(from: params.arguments?["startStopped"], default: false),
                        appPath: params.arguments?["appPath"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_device_processes":
            guard let identifier = params.arguments?["identifier"]?.stringValue else {
                return errorResult("Missing required identifier argument.")
            }
            do {
                return result(for: try AppleDeviceService.processes(identifier: identifier))
            } catch {
                return errorResult(error)
            }
        case "apple_device_terminate":
            guard let identifier = params.arguments?["identifier"]?.stringValue,
                  let processID = intValue(from: params.arguments?["processID"]) else {
                return errorResult("Missing required identifier or processID argument.")
            }
            do {
                return result(
                    for: try AppleDeviceService.terminate(
                        identifier: identifier,
                        processID: processID,
                        force: boolValue(from: params.arguments?["force"], default: false)
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_device_suspend":
            guard let identifier = params.arguments?["identifier"]?.stringValue,
                  let processID = intValue(from: params.arguments?["processID"]) else {
                return errorResult("Missing required identifier or processID argument.")
            }
            do {
                return result(for: try AppleDeviceService.suspend(identifier: identifier, processID: processID))
            } catch {
                return errorResult(error)
            }
        case "apple_device_resume":
            guard let identifier = params.arguments?["identifier"]?.stringValue,
                  let processID = intValue(from: params.arguments?["processID"]) else {
                return errorResult("Missing required identifier or processID argument.")
            }
            do {
                return result(for: try AppleDeviceService.resume(identifier: identifier, processID: processID))
            } catch {
                return errorResult(error)
            }
        case "apple_device_signal":
            guard let identifier = params.arguments?["identifier"]?.stringValue,
                  let processID = intValue(from: params.arguments?["processID"]),
                  let signal = params.arguments?["signal"]?.stringValue else {
                return errorResult("Missing required identifier, processID, or signal argument.")
            }
            do {
                return result(for: try AppleDeviceService.signal(identifier: identifier, processID: processID, signal: signal))
            } catch {
                return errorResult(error)
            }
        case "apple_device_sysdiagnose":
            guard let identifier = params.arguments?["identifier"]?.stringValue,
                  let destination = params.arguments?["destination"]?.stringValue else {
                return errorResult("Missing required identifier or destination argument.")
            }
            do {
                return result(
                    for: try AppleDeviceService.sysdiagnose(
                        identifier: identifier,
                        destination: destination,
                        fullLogs: boolValue(from: params.arguments?["fullLogs"], default: false)
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
