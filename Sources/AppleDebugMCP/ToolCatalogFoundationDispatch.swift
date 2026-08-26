// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppleDebugCore
import MCP

extension ToolCatalog {
    static func dispatchFoundation(
        _ params: CallTool.Parameters,
        context: Context
    ) async -> CallTool.Result? {
        let replay = context.replay
        let kernelLab = context.kernelLab

        switch params.name {
        case "apple_capabilities":
            return result(for: CapabilityMatrix.reports())
        case "apple_debug_reverse_capabilities":
            return result(for: ReverseExecutionService.capabilities())
        case "apple_kernel_capabilities":
            return result(for: AppleKernelCapabilityService.report())
        case "apple_debug_replay_capabilities":
            return result(for: ReplayBackendService.capabilities())
        case "apple_debug_checkpoint":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let label = params.arguments?["label"]?.stringValue else {
                return errorResult("Missing required sessionID or label argument.")
            }
            guard let memoryCaptures = replayMemoryCaptureRequests(
                from: params.arguments?["memoryCaptures"]
            ) else {
                return errorResult("memoryCaptures must contain valid memoryReference, offset, and count objects.")
            }
            guard let determinismManifest = replayStringMap(
                from: params.arguments?["determinismManifest"]
            ) else {
                return errorResult("determinismManifest must be an object of string values.")
            }
            do {
                return result(
                    for: try await replay.capture(
                        sessionID: sessionID,
                        label: label,
                        outputPath: params.arguments?["outputPath"]?.stringValue,
                        memoryCaptures: memoryCaptures,
                        determinismManifest: determinismManifest
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_replay":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let checkpointPath = params.arguments?["checkpointPath"]?.stringValue else {
                return errorResult("Missing required sessionID or checkpointPath argument.")
            }
            do {
                return result(
                    for: try await replay.replay(
                        sessionID: sessionID,
                        checkpointPath: checkpointPath,
                        timeoutMilliseconds: intValue(from: params.arguments?["timeoutMilliseconds"]) ?? 10_000
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_kernel_lab_capabilities":
            return result(for: KernelLabService.capabilities())
        case "apple_kernel_lab_connect":
            guard let host = params.arguments?["host"]?.stringValue,
                  let kernelImagePath = params.arguments?["kernelImagePath"]?.stringValue else {
                return errorResult("Missing required host or kernelImagePath argument.")
            }
            do {
                return result(
                    for: try await kernelLab.connect(
                        configuration: KernelLabConfiguration(
                            host: host,
                            kernelImagePath: kernelImagePath,
                            symbolPath: params.arguments?["symbolPath"]?.stringValue
                        )
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_kernel_lab_inspect":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue else {
                return errorResult("Missing required sessionID argument.")
            }
            do {
                return result(
                    for: try await kernelLab.inspect(
                        sessionID: sessionID,
                        threadID: intValue(from: params.arguments?["threadID"]),
                        frameID: intValue(from: params.arguments?["frameID"]),
                        levels: intValue(from: params.arguments?["levels"]) ?? 64,
                        memoryReference: params.arguments?["memoryReference"]?.stringValue,
                        memoryCount: intValue(from: params.arguments?["memoryCount"])
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_kernel_lab_close":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue else {
                return errorResult("Missing required sessionID argument.")
            }
            return result(for: await kernelLab.close(sessionID: sessionID))
        case "apple_plugin_list":
            guard let directory = params.arguments?["directory"]?.stringValue else {
                return errorResult("Missing required directory argument.")
            }
            do {
                return result(for: try AppleDebugPluginManifestService.discover(directory: directory))
            } catch {
                return errorResult(error)
            }
        case "apple_plugin_host_plan":
            guard let executablePath = params.arguments?["executablePath"]?.stringValue else {
                return errorResult("Missing required executablePath argument.")
            }
            do {
                return result(
                    for: try ApplePluginHostService.plan(
                        executablePath: executablePath,
                        manifestPath: params.arguments?["manifestPath"]?.stringValue,
                        requiredTeamIdentifier: params.arguments?["requiredTeamIdentifier"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_plugin_host_execute":
            guard let executablePath = params.arguments?["executablePath"]?.stringValue,
                  let manifestPath = params.arguments?["manifestPath"]?.stringValue,
                  let input = params.arguments?["input"]?.stringValue else {
                return errorResult("Missing required executablePath, manifestPath, or input argument.")
            }
            do {
                let transport = params.arguments?["transport"]?.stringValue ?? "xpc"
                let requiredTeamIdentifier = params.arguments?["requiredTeamIdentifier"]?.stringValue
                let timeoutSeconds = doubleValue(from: params.arguments?["timeoutSeconds"]) ?? 10.0
                switch transport {
                case "xpc":
                    guard let serviceName = params.arguments?["serviceName"]?.stringValue else {
                        return errorResult("serviceName is required for transport=xpc.")
                    }
                    return result(
                        for: try ApplePluginHostService.executeViaXPC(
                            serviceName: serviceName,
                            executablePath: executablePath,
                            manifestPath: manifestPath,
                            input: input,
                            requiredTeamIdentifier: requiredTeamIdentifier,
                            timeoutSeconds: timeoutSeconds
                        )
                    )
                case "profile":
                    return result(
                        for: try ApplePluginHostService.execute(
                            executablePath: executablePath,
                            manifestPath: manifestPath,
                            input: input,
                            requiredTeamIdentifier: requiredTeamIdentifier,
                            timeoutSeconds: timeoutSeconds
                        )
                    )
                default:
                    return errorResult("transport must be xpc or profile.")
                }
            } catch {
                return errorResult(error)
            }
        case "apple_toolchain_status":
            return result(for: ToolchainProbe.collect())
        case "apple_lldb_dap_initialize":
            let session: LLDBDAPSession
            do {
                session = try LLDBDAPSession()
            } catch {
                return .init(
                    content: [.text(text: error.localizedDescription, annotations: nil, _meta: nil)],
                    isError: true
                )
            }

            do {
                let response = try await session.start()
                let events = await session.drainEvents()
                await session.stop()
                return result(for: DAPProbeResult(response: response, events: events))
            } catch {
                await session.stop()
                return .init(
                    content: [.text(text: error.localizedDescription, annotations: nil, _meta: nil)],
                    isError: true
                )
            }
        default:
            return nil
        }
    }
}
