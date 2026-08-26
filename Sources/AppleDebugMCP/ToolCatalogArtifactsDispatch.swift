// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppleDebugCore
import Foundation
import MCP

extension ToolCatalog {
    static func dispatchArtifacts(
        _ params: CallTool.Parameters,
        context: Context
    ) async -> CallTool.Result? {
        switch params.name {
        case "apple_macho_inspect":
            guard let path = params.arguments?["path"]?.stringValue else {
                return .init(
                    content: [.text(text: "Missing required path argument.", annotations: nil, _meta: nil)],
                    isError: true
                )
            }
            do {
                return result(for: try MachOInspector.inspect(path: path))
            } catch {
                return .init(
                    content: [.text(text: error.localizedDescription, annotations: nil, _meta: nil)],
                    isError: true
                )
            }
        case "apple_binary_inspect":
            guard let path = params.arguments?["path"]?.stringValue else {
                return errorResult("Missing required path argument.")
            }
            do {
                return result(
                    for: try AppleBinaryIntelligenceService.inspect(
                        path: path,
                        architecture: params.arguments?["architecture"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_binary_diff":
            guard let leftPath = params.arguments?["leftPath"]?.stringValue,
                  let rightPath = params.arguments?["rightPath"]?.stringValue else {
                return errorResult("Missing required leftPath or rightPath argument.")
            }
            do {
                return result(
                    for: try AppleBinaryDiffService.diff(
                        leftPath: leftPath,
                        rightPath: rightPath,
                        architecture: params.arguments?["architecture"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_signing_audit":
            guard let path = params.arguments?["path"]?.stringValue else {
                return errorResult("Missing required path argument.")
            }
            do {
                return result(for: try AppleSigningAuditService.inspect(path: path))
            } catch {
                return errorResult(error)
            }
        case "apple_patch_preview":
            guard let path = params.arguments?["path"]?.stringValue,
                  let architecture = params.arguments?["architecture"]?.stringValue,
                  let source = params.arguments?["source"]?.stringValue else {
                return errorResult("Missing required path, architecture, or source argument.")
            }
            let expectedData: Data?
            if let encoded = params.arguments?["expectedData"]?.stringValue {
                guard let decoded = Data(base64Encoded: encoded) else { return errorResult("expectedData must be valid base64.") }
                expectedData = decoded
            } else { expectedData = nil }
            do {
                return result(
                    for: try ApplePatchWorkflowService.preview(
                        path: path,
                        architecture: architecture,
                        fileOffset: intValue(from: params.arguments?["fileOffset"]) ?? 0,
                        source: source,
                        expectedData: expectedData
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_resign_plan":
            guard let inputPath = params.arguments?["inputPath"]?.stringValue,
                  let outputPath = params.arguments?["outputPath"]?.stringValue,
                  let identity = params.arguments?["identity"]?.stringValue else {
                return errorResult("Missing required inputPath, outputPath, or identity argument.")
            }
            do {
                return result(
                    for: try ApplePatchWorkflowService.resignPlan(
                        inputPath: inputPath,
                        outputPath: outputPath,
                        identity: identity,
                        entitlementsPath: params.arguments?["entitlementsPath"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_runtime_metadata":
            guard let path = params.arguments?["path"]?.stringValue else {
                return errorResult("Missing required path argument.")
            }
            do {
                return result(
                    for: try AppleRuntimeMetadataService.inspect(
                        path: path,
                        architecture: params.arguments?["architecture"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_swift_ast_inspect":
            do {
                let moduleName = params.arguments?["moduleName"]?.stringValue ?? "AppleDebugSource"
                let includeRaw = boolValue(from: params.arguments?["includeRaw"], default: false)
                if let projectPath = params.arguments?["projectPath"]?.stringValue {
                    guard let scheme = params.arguments?["scheme"]?.stringValue else {
                        return errorResult("Missing required scheme for projectPath analysis.")
                    }
                    return result(
                        for: try SwiftASTService.inspect(
                            projectPath: projectPath,
                            scheme: scheme,
                            configuration: params.arguments?["configuration"]?.stringValue ?? "Debug",
                            destination: params.arguments?["destination"]?.stringValue ?? "generic/platform=macOS",
                            includeRaw: includeRaw
                        )
                    )
                }
                let paths = stringArray(from: params.arguments?["paths"])
                if !paths.isEmpty {
                    return result(for: try SwiftASTService.inspect(paths: paths, moduleName: moduleName, includeRaw: includeRaw))
                }
                guard let path = params.arguments?["path"]?.stringValue else {
                    return errorResult("Missing required path or paths argument.")
                }
                return result(for: try SwiftASTService.inspect(path: path, moduleName: moduleName, includeRaw: includeRaw))
            } catch {
                return errorResult(error)
            }
        case "apple_assemble":
            guard let source = params.arguments?["source"]?.stringValue,
                  let architecture = params.arguments?["architecture"]?.stringValue else {
                return errorResult("Missing required source or architecture argument.")
            }
            do {
                return result(for: try AppleAssemblerService.assemble(source: source, architecture: architecture))
            } catch {
                return errorResult(error)
            }
        case "apple_control_flow":
            guard let path = params.arguments?["path"]?.stringValue,
                  let architecture = params.arguments?["architecture"]?.stringValue else {
                return errorResult("Missing required path or architecture argument.")
            }
            do {
                return result(for: try AppleControlFlowService.analyze(path: path, architecture: architecture))
            } catch {
                return errorResult(error)
            }
        case "apple_dyld_shared_cache_inspect":
            guard let path = params.arguments?["path"]?.stringValue else {
                return errorResult("Missing required path argument.")
            }
            do {
                return result(
                    for: try AppleDyldSharedCacheService.inspect(
                        path: path,
                        imageFilter: params.arguments?["imageFilter"]?.stringValue,
                        maximumImages: intValue(from: params.arguments?["maximumImages"]) ?? 10_000
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_dyld_shared_cache_image_analyze":
            guard let path = params.arguments?["path"]?.stringValue,
                  let imagePath = params.arguments?["imagePath"]?.stringValue else {
                return errorResult("Missing required path or imagePath argument.")
            }
            do {
                return result(
                    for: try AppleDyldSharedCacheService.analyzeImage(
                        path: path,
                        imagePath: imagePath,
                        maximumExports: intValue(from: params.arguments?["maximumExports"]) ?? 5_000,
                        maximumSymbols: intValue(from: params.arguments?["maximumSymbols"]) ?? 5_000
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_dyld_shared_cache_discover":
            return result(for: AppleDyldSharedCacheService.discover())
        case "apple_dwarf_inspect":
            guard let path = params.arguments?["path"]?.stringValue else {
                return errorResult("Missing required path argument.")
            }
            do {
                return result(
                    for: try DWARFService.inspect(
                        path: path,
                        architecture: params.arguments?["architecture"]?.stringValue,
                        name: params.arguments?["name"]?.stringValue,
                        lookupAddress: params.arguments?["lookupAddress"]?.stringValue,
                        depth: intValue(from: params.arguments?["depth"]) ?? 3,
                        includeSources: boolValue(
                            from: params.arguments?["includeSources"],
                            default: true
                        ),
                        includeStatistics: boolValue(
                            from: params.arguments?["includeStatistics"],
                            default: true
                        ),
                        includeLineTable: boolValue(
                            from: params.arguments?["includeLineTable"],
                            default: true
                        ),
                        includeRaw: boolValue(
                            from: params.arguments?["includeRaw"],
                            default: false
                        )
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_crash_inspect":
            guard let path = params.arguments?["path"]?.stringValue else {
                return errorResult("Missing required path argument.")
            }
            do {
                return result(for: try CrashReportAnalyzer.inspect(path: path))
            } catch {
                return errorResult(error)
            }
        case "apple_crash_symbolicate":
            guard let crashPath = params.arguments?["crashPath"]?.stringValue,
                  let artifacts = crashArtifacts(from: params.arguments?["artifacts"]) else {
                return errorResult("Missing required crashPath or valid artifacts array argument.")
            }
            do {
                return result(
                    for: try CrashSymbolicationService.symbolize(
                        path: crashPath,
                        artifacts: artifacts
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_log_show":
            do {
                return result(
                    for: try AppleLogService.show(
                        target: params.arguments?["target"]?.stringValue ?? "host",
                        last: params.arguments?["last"]?.stringValue ?? "5m",
                        predicate: params.arguments?["predicate"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_symbolicate":
            guard let binaryPath = params.arguments?["binaryPath"]?.stringValue,
                  let architecture = params.arguments?["architecture"]?.stringValue,
                  let address = params.arguments?["address"]?.stringValue else {
                return errorResult("Missing required binaryPath, architecture, or address argument.")
            }
            do {
                return result(
                    for: try SymbolicationService.symbolize(
                        binaryPath: binaryPath,
                        architecture: architecture,
                        address: address,
                        loadAddress: params.arguments?["loadAddress"]?.stringValue
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
