// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppleDebugCore
import MCP

extension ToolCatalog {
    static func dispatchXcode(
        _ params: CallTool.Parameters,
        context: Context
    ) async -> CallTool.Result? {
        switch params.name {
        case "apple_xcode_discover":
            guard let path = params.arguments?["path"]?.stringValue else {
                return errorResult("Missing required path argument.")
            }
            do {
                return result(for: try XcodeService.discover(path: path))
            } catch {
                return errorResult(error)
            }
        case "apple_xcode_build":
            guard let path = params.arguments?["path"]?.stringValue,
                  let scheme = params.arguments?["scheme"]?.stringValue,
                  let destination = params.arguments?["destination"]?.stringValue else {
                return errorResult("Missing required path, scheme, or destination argument.")
            }
            let configuration = params.arguments?["configuration"]?.stringValue ?? "Debug"
            do {
                return result(
                    for: try XcodeService.build(
                        path: path,
                        scheme: scheme,
                        configuration: configuration,
                        destination: destination,
                        derivedDataPath: params.arguments?["derivedDataPath"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_xcode_test":
            guard let path = params.arguments?["path"]?.stringValue,
                  let scheme = params.arguments?["scheme"]?.stringValue,
                  let destination = params.arguments?["destination"]?.stringValue else {
                return errorResult("Missing required path, scheme, or destination argument.")
            }
            do {
                return result(
                    for: try XcodeService.test(
                        path: path,
                        scheme: scheme,
                        configuration: params.arguments?["configuration"]?.stringValue ?? "Debug",
                        destination: destination,
                        derivedDataPath: params.arguments?["derivedDataPath"]?.stringValue,
                        resultBundlePath: params.arguments?["resultBundlePath"]?.stringValue,
                        codeSigningAllowed: boolValue(
                            from: params.arguments?["codeSigningAllowed"],
                            default: true
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
