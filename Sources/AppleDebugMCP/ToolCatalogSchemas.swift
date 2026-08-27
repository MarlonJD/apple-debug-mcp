// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import MCP

extension ToolCatalog {
    static let emptyObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([:])
    ])

    static let pluginListObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "directory": .object([
                "type": .string("string"),
                "description": .string("Absolute directory containing *.appledebugplugin.json manifests")
            ])
        ]),
        "required": .array([.string("directory")])
    ])

    static let pluginHostPlanObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "executablePath": .object(["type": .string("string")]),
            "manifestPath": .object(["type": .string("string")]),
            "requiredTeamIdentifier": .object(["type": .string("string")])
        ]),
        "required": .array([.string("executablePath")])
    ])

    static let pluginHostExecuteObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "executablePath": .object(["type": .string("string")]),
            "manifestPath": .object(["type": .string("string")]),
            "input": .object([
                "type": .string("string"),
                "description": .string("Bounded UTF-8 JSON-line input delivered through the plugin XPC protocol")
            ]),
            "requiredTeamIdentifier": .object(["type": .string("string")]),
            "timeoutSeconds": .object(["type": .string("number")]),
            "transport": .object([
                "type": .string("string"),
                "enum": .array([.string("xpc"), .string("profile")]),
                "description": .string("Defaults to embedded App Sandbox XPC; profile is an explicit legacy diagnostic transport")
            ]),
            "serviceName": .object([
                "type": .string("string"),
                "description": .string("Embedded XPC service bundle identifier; must match the manifest id for transport=xpc")
            ])
        ]),
        "required": .array([.string("executablePath"), .string("manifestPath"), .string("input")])
    ])

    static let pathObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Absolute path to an authorized Mach-O file")
            ])
        ]),
        "required": .array([.string("path")])
    ])

    static let binaryInspectObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Absolute path to an authorized Mach-O binary")
            ]),
            "architecture": .object([
                "type": .string("string"),
                "description": .string("Optional architecture such as arm64e or x86_64")
            ])
        ]),
        "required": .array([.string("path")])
    ])

    static let assembleObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "architecture": .object([
                "type": .string("string"),
                "enum": .array([.string("arm64"), .string("x86_64")])
            ]),
            "source": .object([
                "type": .string("string"),
                "description": .string("Bounded self-contained Apple assembly source; maximum 64 KiB")
            ])
        ]),
        "required": .array([.string("architecture"), .string("source")])
    ])

    static let patchPreviewObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object(["type": .string("string")]),
            "architecture": .object([
                "type": .string("string"),
                "enum": .array([.string("arm64"), .string("x86_64")])
            ]),
            "fileOffset": .object(["type": .string("integer")]),
            "source": .object(["type": .string("string")]),
            "expectedData": .object(["type": .string("string"), "description": .string("Optional base64 expected bytes")])
        ]),
        "required": .array([.string("path"), .string("architecture"), .string("source")])
    ])

    static let resignPlanObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "inputPath": .object(["type": .string("string")]),
            "outputPath": .object(["type": .string("string")]),
            "identity": .object(["type": .string("string")]),
            "entitlementsPath": .object(["type": .string("string")])
        ]),
        "required": .array([.string("inputPath"), .string("outputPath"), .string("identity")])
    ])

    static let controlFlowObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Absolute Mach-O or app executable path")
            ]),
            "architecture": .object([
                "type": .string("string"),
                "enum": .array([.string("arm64"), .string("arm64e"), .string("x86_64")])
            ])
        ]),
        "required": .array([.string("path"), .string("architecture")])
    ])

    static let dyldSharedCacheObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Absolute dyld_shared_cache file path")
            ]),
            "imageFilter": .object([
                "type": .string("string"),
                "description": .string("Optional bounded case-insensitive image path filter")
            ]),
            "maximumImages": .object([
                "type": .string("integer"),
                "description": .string("Maximum returned images from 1 to 10000")
            ])
        ]),
        "required": .array([.string("path")])
    ])

    static let dyldSharedCacheImageObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Absolute dyld_shared_cache file path")
            ]),
            "imagePath": .object([
                "type": .string("string"),
                "description": .string("Exact image path from the shared-cache image table")
            ]),
            "maximumExports": .object([
                "type": .string("integer"),
                "description": .string("Maximum decoded export-trie entries from 1 to 20000")
            ]),
            "maximumSymbols": .object([
                "type": .string("integer"),
                "description": .string("Maximum decoded nlist symbols from 1 to 20000")
            ])
        ]),
        "required": .array([.string("path"), .string("imagePath")])
    ])

    static let binaryDiffObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "leftPath": .object([
                "type": .string("string"),
                "description": .string("Regular Mach-O path, .app bundle, or .dSYM bundle")
            ]),
            "rightPath": .object([
                "type": .string("string"),
                "description": .string("Regular Mach-O path, .app bundle, or .dSYM bundle")
            ]),
            "architecture": .object([
                "type": .string("string"),
                "description": .string("Optional Mach-O architecture such as arm64 or x86_64")
            ])
        ]),
        "required": .array([.string("leftPath"), .string("rightPath")])
    ])

    static let swiftASTObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Absolute .swift source file path")
            ]),
            "paths": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")]),
                "description": .string("Optional bounded multi-file Swift source set in one module")
            ]),
            "projectPath": .object([
                "type": .string("string"),
                "description": .string("Optional .xcodeproj or .xcworkspace path for target-aware source/module analysis")
            ]),
            "scheme": .object([
                "type": .string("string"),
                "description": .string("Xcode scheme used with projectPath")
            ]),
            "configuration": .object(["type": .string("string")]),
            "destination": .object([
                "type": .string("string"),
                "description": .string("xcodebuild destination used to resolve SDK and target triple")
            ]),
            "moduleName": .object([
                "type": .string("string"),
                "description": .string("Bounded Swift module name passed to public swiftc")
            ]),
            "includeRaw": .object([
                "type": .string("boolean"),
                "description": .string("Include bounded raw swiftc AST text")
            ])
        ]),
        "required": .array([])
    ])

    static let dwarfInspectObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Mach-O binary or .dSYM bundle")
            ]),
            "architecture": .object(["type": .string("string")]),
            "name": .object([
                "type": .string("string"),
                "description": .string("Optional exact DW_AT_name query")
            ]),
            "lookupAddress": .object([
                "type": .string("string"),
                "description": .string("Optional hexadecimal address for dwarfdump source lookup")
            ]),
            "depth": .object([
                "type": .string("integer"),
                "description": .string("DWARF child recursion depth from 1 to 8; defaults to 3")
            ]),
            "includeSources": .object(["type": .string("boolean")]),
            "includeStatistics": .object(["type": .string("boolean")]),
            "includeLineTable": .object([
                "type": .string("boolean"),
                "description": .string("Include bounded DWARF line-table address/source rows")
            ]),
            "includeRaw": .object([
                "type": .string("boolean"),
                "description": .string("Include bounded raw debug-info output")
            ])
        ]),
        "required": .array([.string("path")])
    ])

    static let sessionCreateObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "deviceIdentifier": .object([
                "type": .string("string"),
                "description": .string("Optional CoreDevice UUID or legacy xcdevice UDID")
            ]),
            "appPath": .object([
                "type": .string("string"),
                "description": .string("Signed .app path; required for legacy LLDB-DAP and recommended for CoreDevice symbols/PID discovery")
            ])
        ])
    ])

    static let crashObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Absolute path to an authorized .crash or .ips report")
            ])
        ]),
        "required": .array([.string("path")])
    ])

    static let crashSymbolicateObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "crashPath": .object([
                "type": .string("string"),
                "description": .string("Absolute path to an authorized .crash or .ips report")
            ]),
            "artifacts": .object([
                "type": .string("array"),
                "description": .string("Up to 32 explicit executable/app or dSYM providers; one exact dSYM may provide image identity when no executable is supplied"),
                "items": .object([
                    "type": .string("object"),
                    "properties": .object([
                        "imageName": .object(["type": .string("string")]),
                        "binaryPath": .object(["type": .string("string")]),
                        "architecture": .object(["type": .string("string")]),
                        "dSYMPath": .object([
                            "type": .string("string"),
                            "description": .string("Optional explicit absolute dSYM provider paired with this executable")
                        ])
                    ]),
                    "required": .array([
                        .string("binaryPath"),
                        .string("architecture")
                    ])
                ])
            ])
        ]),
        "required": .array([.string("crashPath"), .string("artifacts")])
    ])

    static let logShowObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "target": .object([
                "type": .string("string"),
                "description": .string("host or an available iOS Simulator UDID")
            ]),
            "last": .object([
                "type": .string("string"),
                "description": .string("Bounded duration such as 30s, 5m, 1h, or 1d")
            ]),
            "predicate": .object(["type": .string("string")])
        ])
    ])

    static let sessionObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object([
                "type": .string("string"),
                "description": .string("Active Apple Debug MCP session identifier")
            ])
        ]),
        "required": .array([.string("sessionID")])
    ])

    static let kernelLabConnectObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "host": .object([
                "type": .string("string"),
                "description": .string("Authorized remote KDP hostname or IP address")
            ]),
            "kernelImagePath": .object([
                "type": .string("string"),
                "description": .string("Absolute KDK/debug-kernel image path")
            ]),
            "symbolPath": .object([
                "type": .string("string"),
                "description": .string("Optional absolute kernel symbol file path")
            ])
        ]),
        "required": .array([.string("host"), .string("kernelImagePath")])
    ])

    static let kernelLabInspectObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "threadID": .object(["type": .string("integer")]),
            "frameID": .object(["type": .string("integer")]),
            "levels": .object([
                "type": .string("integer"),
                "description": .string("Stack depth from 1 to 256; defaults to 64")
            ]),
            "memoryReference": .object([
                "type": .string("string"),
                "description": .string("Optional bounded hexadecimal kernel address")
            ]),
            "memoryCount": .object([
                "type": .string("integer"),
                "description": .string("Optional read-only memory length from 1 to 65536")
            ])
        ]),
        "required": .array([.string("sessionID")])
    ])

    static let launchObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "program": .object(["type": .string("string")]),
            "args": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")])
            ]),
            "stopOnEntry": .object(["type": .string("boolean")])
        ]),
        "required": .array([.string("sessionID"), .string("program")])
    ])

    static let replayCheckpointObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "label": .object([
                "type": .string("string"),
                "description": .string("Human-readable checkpoint label, maximum 256 UTF-8 bytes")
            ]),
            "outputPath": .object([
                "type": .string("string"),
                "description": .string("Optional absolute non-existing JSON path; defaults to a temporary artifact")
            ]),
            "memoryCaptures": .object([
                "type": .string("array"),
                "description": .string("Optional bounded memory evidence captures"),
                "items": .object([
                    "type": .string("object"),
                    "properties": .object([
                        "memoryReference": .object(["type": .string("string")]),
                        "offset": .object(["type": .string("integer")]),
                        "count": .object(["type": .string("integer")])
                    ]),
                    "required": .array([.string("memoryReference"), .string("count")])
                ])
            ]),
            "determinismManifest": .object([
                "type": .string("object"),
                "description": .string("Optional string metadata describing replay inputs such as seed or fixture version")
            ])
        ]),
        "required": .array([.string("sessionID"), .string("label")])
    ])

    static let replayObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "checkpointPath": .object([
                "type": .string("string"),
                "description": .string("Absolute path to a replay checkpoint JSON artifact")
            ]),
            "timeoutMilliseconds": .object([
                "type": .string("integer"),
                "description": .string("Stop wait timeout from 1 to 120000 milliseconds")
            ])
        ]),
        "required": .array([.string("sessionID"), .string("checkpointPath")])
    ])

    static let attachObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "processID": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("processID")])
    ])

    static let processObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "processID": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("processID")])
    ])

    static let runtimeDiagnosticObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "processID": .object(["type": .string("integer")]),
            "tool": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("heap"), .string("leaks"), .string("malloc_history"), .string("sample")
                ])
            ]),
            "mode": .object([
                "type": .string("string"),
                "description": .string("heap: summary/addresses/layouts/zones; leaks: summary/list/fullStacks; malloc_history: callTree/allBySize/allByCount/allEvents; sample: sample")
            ]),
            "pattern": .object([
                "type": .string("string"),
                "description": .string("Optional bounded class/symbol pattern for heap or malloc_history")
            ]),
            "durationSeconds": .object([
                "type": .string("integer"),
                "description": .string("sample duration from 1 to 30 seconds; defaults to 5")
            ]),
            "sampleIntervalMilliseconds": .object([
                "type": .string("integer"),
                "description": .string("sample interval from 1 to 1000 milliseconds; defaults to 10")
            ])
        ]),
        "required": .array([.string("processID"), .string("tool")])
    ])

    static let memorySnapshotObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "processID": .object(["type": .string("integer")]),
            "outputPath": .object([
                "type": .string("string"),
                "description": .string("Absolute non-existing .json snapshot path")
            ]),
            "includeRawOutput": .object(["type": .string("boolean")])
        ]),
        "required": .array([.string("processID"), .string("outputPath")])
    ])

    static let memoryDiffObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "leftPath": .object(["type": .string("string")]),
            "rightPath": .object(["type": .string("string")])
        ]),
        "required": .array([.string("leftPath"), .string("rightPath")])
    ])

    static let performanceRecordObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "processID": .object(["type": .string("integer")]),
            "simulatorUDID": .object(["type": .string("string")]),
            "coreDeviceIdentifier": .object([
                "type": .string("string"),
                "description": .string("Paired CoreDevice UUID for physical-device capture")
            ]),
            "template": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("Time Profiler"),
                    .string("Allocations"),
                    .string("System Trace"),
                    .string("Power Profiler"),
                    .string("Animation Hitches"),
                    .string("Swift Concurrency"),
                    .string("Processor Trace"),
                    .string("CPU Profiler"),
                    .string("Leaks"),
                    .string("Network"),
                    .string("File Activity"),
                    .string("Logging"),
                    .string("Game Performance")
                ])
            ]),
            "durationSeconds": .object([
                "type": .string("integer"),
                "description": .string("Recording duration from 1 to 60 seconds; defaults to 5")
            ]),
            "outputPath": .object([
                "type": .string("string"),
                "description": .string("Absolute non-existing .trace output path")
            ])
        ]),
        "required": .array([.string("outputPath")])
    ])

    static let performanceAnalyzeObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "tracePath": .object([
                "type": .string("string"),
                "description": .string("Absolute existing .trace bundle produced by apple_performance_record")
            ]),
            "schema": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("time-profile"), .string("time-sample"), .string("allocations"),
                    .string("allocation"), .string("os-signpost"), .string("os-log"),
                    .string("animation-hitch"), .string("animation-hitches"), .string("power"),
                    .string("energy"), .string("core-animation"), .string("swift-concurrency"),
                    .string("thread-info"), .string("process-info"), .string("signpost"),
                    .string("swift-task-state"), .string("swift-actor-count"),
                    .string("swift-task-cancellation-event"), .string("swift-total-task-count"),
                    .string("swift-actor-lifetime"), .string("swift-actor-execution"),
                    .string("swift-task-creation-event"), .string("swift-actor-queue-size"),
                    .string("swift-task-relationship"), .string("swift-alive-task-count"),
                    .string("swift-task-lifetime"), .string("swift-running-task-count")
                ])
            ]),
            "maximumRows": .object([
                "type": .string("integer"),
                "description": .string("Maximum exported rows from 1 to 5000; defaults to 5000")
            ]),
            "includeRows": .object([
                "type": .string("boolean"),
                "description": .string("Include parsed rows in addition to hotspots and folded flame stacks")
            ])
        ]),
        "required": .array([.string("tracePath")])
    ])

    static let performanceSemanticReportObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "tracePath": .object([
                "type": .string("string"),
                "description": .string("Absolute existing .trace bundle produced by apple_performance_record")
            ]),
            "schema": .object([
                "type": .string("string"),
                "description": .string("Allowlisted xctrace schema such as allocations, power, animation-hitches, os-signpost, or swift-concurrency")
            ]),
            "maximumRows": .object([
                "type": .string("integer"),
                "description": .string("Maximum exported rows from 1 to 5000; defaults to 5000")
            ])
        ]),
        "required": .array([.string("tracePath")])
    ])

    static let performanceTimelineObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "tracePath": .object(["type": .string("string")]),
            "schema": .object(["type": .string("string")]),
            "maximumRows": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("tracePath")])
    ])

    static let performanceDiffObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "leftTracePath": .object(["type": .string("string")]),
            "rightTracePath": .object(["type": .string("string")]),
            "schema": .object(["type": .string("string")]),
            "maximumRows": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("leftTracePath"), .string("rightTracePath")])
    ])

    static let swiftConcurrencyGraphObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "tracePath": .object(["type": .string("string")]),
            "maximumRows": .object([
                "type": .string("integer"),
                "description": .string("Maximum Swift Concurrency export rows from 1 to 5000")
            ])
        ]),
        "required": .array([.string("tracePath")])
    ])

    static let breakpointObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "file": .object(["type": .string("string")]),
            "line": .object(["type": .string("integer")]),
            "condition": .object(["type": .string("string")]),
            "hitCondition": .object(["type": .string("string")]),
            "logMessage": .object(["type": .string("string")])
        ]),
        "required": .array([.string("sessionID"), .string("file"), .string("line")])
    ])

    static let breakpointLocationsObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "file": .object(["type": .string("string")]),
            "line": .object(["type": .string("integer")]),
            "column": .object(["type": .string("integer")]),
            "endLine": .object(["type": .string("integer")]),
            "endColumn": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("file"), .string("line")])
    ])

    static let instructionBreakpointObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "instructionReference": .object(["type": .string("string")]),
            "offset": .object(["type": .string("integer")]),
            "condition": .object(["type": .string("string")]),
            "hitCondition": .object(["type": .string("string")]),
            "logMessage": .object(["type": .string("string")])
        ]),
        "required": .array([.string("sessionID"), .string("instructionReference")])
    ])

    static let functionBreakpointObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "name": .object(["type": .string("string")]),
            "condition": .object(["type": .string("string")]),
            "hitCondition": .object(["type": .string("string")])
        ]),
        "required": .array([.string("sessionID"), .string("name")])
    ])

    static let exceptionBreakpointObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "filters": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")])
            ]),
            "filterOptions": .object([
                "type": .string("array"),
                "items": .object([
                    "type": .string("object"),
                    "properties": .object([
                        "filter": .object(["type": .string("string")]),
                        "condition": .object(["type": .string("string")])
                    ]),
                    "required": .array([.string("filter")])
                ])
            ])
        ]),
        "required": .array([.string("sessionID"), .string("filters")])
    ])

    static let threadObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "threadID": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("threadID")])
    ])

    static let stepObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "threadID": .object(["type": .string("integer")]),
            "kind": .object([
                "type": .string("string"),
                "enum": .array([.string("stepIn"), .string("next"), .string("stepOut")])
            ]),
            "granularity": .object([
                "type": .string("string"),
                "enum": .array([.string("statement"), .string("line"), .string("instruction")])
            ])
        ]),
        "required": .array([.string("sessionID"), .string("threadID"), .string("kind")])
    ])

    static let forwardTraceObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "threadID": .object(["type": .string("integer")]),
            "steps": .object([
                "type": .string("integer"),
                "description": .string("Number of forward steps from 1 to 100")
            ]),
            "kind": .object([
                "type": .string("string"),
                "enum": .array([.string("stepIn"), .string("next"), .string("stepOut")])
            ]),
            "granularity": .object([
                "type": .string("string"),
                "enum": .array([.string("statement"), .string("line"), .string("instruction")])
            ]),
            "timeoutMilliseconds": .object([
                "type": .string("integer"),
                "description": .string("Per-step stop timeout up to 120000 milliseconds")
            ])
        ]),
        "required": .array([
            .string("sessionID"), .string("threadID"), .string("steps"), .string("kind")
        ])
    ])

    static let frameObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "frameID": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("frameID")])
    ])

    static let variablesObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "variablesReference": .object(["type": .string("integer")]),
            "start": .object(["type": .string("integer")]),
            "count": .object(["type": .string("integer")]),
            "formatHex": .object(["type": .string("boolean")])
        ]),
        "required": .array([.string("sessionID"), .string("variablesReference")])
    ])

    static let completionsObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "frameID": .object(["type": .string("integer")]),
            "text": .object(["type": .string("string")]),
            "column": .object(["type": .string("integer")]),
            "line": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("text"), .string("column")])
    ])

    static let setVariableObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "variablesReference": .object(["type": .string("integer")]),
            "name": .object(["type": .string("string")]),
            "value": .object(["type": .string("string")])
        ]),
        "required": .array([
            .string("sessionID"),
            .string("variablesReference"),
            .string("name"),
            .string("value")
        ])
    ])

    static let moduleObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "startModule": .object(["type": .string("integer")]),
            "moduleCount": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID")])
    ])

    static let stopSnapshotObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "threadID": .object(["type": .string("integer")]),
            "levels": .object([
                "type": .string("integer"),
                "description": .string("Maximum stack depth; defaults to 20")
            ])
        ]),
        "required": .array([.string("sessionID")])
    ])

    static let waitForStopObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "timeoutMilliseconds": .object([
                "type": .string("integer"),
                "description": .string("Positive timeout in milliseconds; maximum 120000; defaults to 10000")
            ])
        ]),
        "required": .array([.string("sessionID")])
    ])

    static let evaluateObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "expression": .object(["type": .string("string")]),
            "frameID": .object(["type": .string("integer")]),
            "context": .object(["type": .string("string")])
        ]),
        "required": .array([.string("sessionID"), .string("expression")])
    ])

    static let dataBreakpointInfoObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "variablesReference": .object(["type": .string("integer")]),
            "name": .object(["type": .string("string")])
        ]),
        "required": .array([.string("sessionID"), .string("variablesReference"), .string("name")])
    ])

    static let dataBreakpointObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "dataID": .object(["type": .string("string")]),
            "accessType": .object([
                "type": .string("string"),
                "enum": .array([.string("read"), .string("write"), .string("readWrite")])
            ])
        ]),
        "required": .array([.string("sessionID"), .string("dataID")])
    ])

    static let writeMemoryObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "memoryReference": .object(["type": .string("string")]),
            "offset": .object(["type": .string("integer")]),
            "data": .object([
                "type": .string("string"),
                "description": .string("Base64-encoded bytes; maximum 4096 bytes")
            ])
        ]),
        "required": .array([.string("sessionID"), .string("memoryReference"), .string("data")])
    ])

    static let searchMemoryObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "memoryReference": .object(["type": .string("string")]),
            "offset": .object(["type": .string("integer")]),
            "count": .object(["type": .string("integer")]),
            "pattern": .object([
                "type": .string("string"),
                "description": .string("Base64-encoded byte pattern")
            ])
        ]),
        "required": .array([
            .string("sessionID"),
            .string("memoryReference"),
            .string("count"),
            .string("pattern")
        ])
    ])

    static let patchMemoryObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "memoryReference": .object(["type": .string("string")]),
            "offset": .object(["type": .string("integer")]),
            "expectedData": .object([
                "type": .string("string"),
                "description": .string("Optional base64 bytes that must match before writing")
            ]),
            "data": .object([
                "type": .string("string"),
                "description": .string("Base64 bytes to write; maximum 4096 bytes")
            ])
        ]),
        "required": .array([
            .string("sessionID"),
            .string("memoryReference"),
            .string("data")
        ])
    ])

    static let patchAssemblyObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "memoryReference": .object(["type": .string("string")]),
            "offset": .object(["type": .string("integer")]),
            "architecture": .object([
                "type": .string("string"),
                "enum": .array([.string("arm64"), .string("x86_64")])
            ]),
            "source": .object([
                "type": .string("string"),
                "description": .string("Bounded self-contained Apple assembly source; emitted code is limited to 4096 bytes")
            ]),
            "expectedData": .object([
                "type": .string("string"),
                "description": .string("Optional base64 bytes required at the target before patching")
            ])
        ]),
        "required": .array([
            .string("sessionID"), .string("memoryReference"),
            .string("architecture"), .string("source")
        ])
    ])

    static let terminateObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "terminateDebuggee": .object(["type": .string("boolean")])
        ]),
        "required": .array([.string("sessionID")])
    ])

    static let stackTraceObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "threadID": .object(["type": .string("integer")]),
            "levels": .object(["type": .string("integer")]),
            "startFrame": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("threadID")])
    ])

    static let memoryObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "memoryReference": .object(["type": .string("string")]),
            "offset": .object(["type": .string("integer")]),
            "count": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("memoryReference"), .string("count")])
    ])

    static let disassembleObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "memoryReference": .object(["type": .string("string")]),
            "instructionOffset": .object(["type": .string("integer")]),
            "instructionCount": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("memoryReference"), .string("instructionCount")])
    ])

    static let simulatorObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")])
        ]),
        "required": .array([.string("udid")])
    ])

    static let simulatorInstallObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "appPath": .object(["type": .string("string")])
        ]),
        "required": .array([.string("udid"), .string("appPath")])
    ])

    static let simulatorLaunchObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "bundleID": .object(["type": .string("string")]),
            "arguments": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")])
            ]),
            "terminateRunning": .object(["type": .string("boolean")]),
            "waitForDebugger": .object(["type": .string("boolean")])
        ]),
        "required": .array([.string("udid"), .string("bundleID")])
    ])

    static let simulatorScreenshotObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "path": .object([
                "type": .string("string"),
                "description": .string("Optional absolute PNG output path; defaults to a temporary file")
            ])
        ]),
        "required": .array([.string("udid")])
    ])

    static let simulatorURLObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "url": .object(["type": .string("string")])
        ]),
        "required": .array([.string("udid"), .string("url")])
    ])

    static let simulatorLocationObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "latitude": .object(["type": .string("number")]),
            "longitude": .object(["type": .string("number")])
        ]),
        "required": .array([.string("udid"), .string("latitude"), .string("longitude")])
    ])

    static let simulatorRecordVideoObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "path": .object(["type": .string("string")]),
            "durationSeconds": .object([
                "type": .string("integer"),
                "description": .string("Recording duration from 1 to 60 seconds; defaults to 1")
            ]),
            "codec": .object([
                "type": .string("string"),
                "enum": .array([.string("h264"), .string("hevc")]),
                "description": .string("Video codec; defaults to hevc, matching simctl's current public default")
            ]),
            "display": .object(["type": .string("string")])
        ]),
        "required": .array([.string("udid"), .string("path")])
    ])

    static let simulatorAppInfoObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "bundleID": .object(["type": .string("string")])
        ]),
        "required": .array([.string("udid"), .string("bundleID")])
    ])

    static let simulatorContainerObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "bundleID": .object(["type": .string("string")]),
            "container": .object([
                "type": .string("string"),
                "description": .string("app, data, groups, or a specific app-group identifier")
            ])
        ]),
        "required": .array([.string("udid"), .string("bundleID")])
    ])

    static let simulatorEnvironmentObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "operation": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("status_bar_list"), .string("status_bar_override"), .string("status_bar_clear"),
                    .string("ui_get"), .string("ui_set"), .string("privacy"), .string("push"),
                    .string("pasteboard_get"), .string("pasteboard_set"), .string("keychain_reset"),
                    .string("getenv"), .string("list_apps"), .string("add_media")
                ])
            ]),
            "bundleID": .object(["type": .string("string")]),
            "service": .object(["type": .string("string")]),
            "value": .object(["type": .string("string")]),
            "variable": .object(["type": .string("string")]),
            "payload": .object(["type": .string("object")]),
            "mediaPaths": .object(["type": .string("array"), "items": .object(["type": .string("string")])]),
            "statusOverrides": .object([
                "type": .string("object"),
                "description": .string("Fixed status-bar override keys: time, dataNetwork, wifiMode, wifiBars, cellularMode, cellularBars, operatorName, batteryState, batteryLevel")
            ])
        ]),
        "required": .array([.string("udid"), .string("operation")])
    ])

    static let simulatorReproBundleObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "bundleID": .object(["type": .string("string")]),
            "outputDirectory": .object([
                "type": .string("string"),
                "description": .string("Absolute non-existing output directory")
            ]),
            "includeScreenshot": .object(["type": .string("boolean")]),
            "includeAppInfo": .object(["type": .string("boolean")]),
            "includeLogs": .object(["type": .string("boolean")]),
            "tracePaths": .object(["type": .string("array"), "items": .object(["type": .string("string")])]),
            "crashPath": .object(["type": .string("string")])
        ]),
        "required": .array([.string("udid"), .string("bundleID"), .string("outputDirectory")])
    ])

    static let simulatorUISnapshotObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "bundleID": .object(["type": .string("string")]),
            "projectPath": .object([
                "type": .string("string"),
                "description": .string("Path to an Xcode project or workspace with a UI-test-enabled scheme")
            ]),
            "scheme": .object(["type": .string("string")]),
            "configuration": .object(["type": .string("string")])
        ]),
        "required": .array([
            .string("udid"),
            .string("bundleID"),
            .string("projectPath"),
            .string("scheme")
        ])
    ])

    static let simulatorUIActionObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "bundleID": .object(["type": .string("string")]),
            "projectPath": .object(["type": .string("string")]),
            "scheme": .object(["type": .string("string")]),
            "configuration": .object(["type": .string("string")]),
            "action": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("tap"),
                    .string("doubleTap"),
                    .string("longPress"),
                    .string("typeText"),
                    .string("swipe"),
                    .string("pinch"),
                    .string("wait"),
                    .string("coordinateTap"),
                    .string("coordinateLongPress"),
                    .string("coordinateSwipe")
                ])
            ]),
            "identifier": .object(["type": .string("string")]),
            "text": .object(["type": .string("string")]),
            "durationSeconds": .object(["type": .string("number")]),
            "scale": .object(["type": .string("number")]),
            "velocity": .object(["type": .string("number")]),
            "x": .object([
                "type": .string("number"),
                "description": .string("Normalized horizontal coordinate from 0.0 to 1.0 for coordinate actions")
            ]),
            "y": .object([
                "type": .string("number"),
                "description": .string("Normalized vertical coordinate from 0.0 to 1.0 for coordinate actions")
            ]),
            "endX": .object(["type": .string("number")]),
            "endY": .object(["type": .string("number")]),
            "direction": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("up"),
                    .string("down"),
                    .string("left"),
                    .string("right")
                ])
            ])
        ]),
        "required": .array([
            .string("udid"),
            .string("bundleID"),
            .string("projectPath"),
            .string("scheme"),
            .string("action")
        ])
    ])

    static let simulatorUIProbeObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "bundleID": .object([
                "type": .string("string"),
                "description": .string("Bundle identifier of an application already installed in the selected Simulator")
            ]),
            "configuration": .object(["type": .string("string")])
        ]),
        "required": .array([.string("udid"), .string("bundleID")])
    ])

    static let simulatorUIProbeActionObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "bundleID": .object(["type": .string("string")]),
            "configuration": .object(["type": .string("string")]),
            "action": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("tap"), .string("doubleTap"), .string("longPress"),
                    .string("typeText"), .string("swipe"), .string("pinch"), .string("wait")
                    , .string("coordinateTap"), .string("coordinateLongPress"), .string("coordinateSwipe")
                ])
            ]),
            "identifier": .object(["type": .string("string")]),
            "text": .object(["type": .string("string")]),
            "durationSeconds": .object(["type": .string("number")]),
            "scale": .object(["type": .string("number")]),
            "velocity": .object(["type": .string("number")]),
            "x": .object(["type": .string("number")]),
            "y": .object(["type": .string("number")]),
            "endX": .object(["type": .string("number")]),
            "endY": .object(["type": .string("number")]),
            "direction": .object([
                "type": .string("string"),
                "enum": .array([.string("up"), .string("down"), .string("left"), .string("right")])
            ])
        ]),
        "required": .array([.string("udid"), .string("bundleID"), .string("action")])
    ])

    static let deviceInstallObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "identifier": .object(["type": .string("string")]),
            "appPath": .object(["type": .string("string")])
        ]),
        "required": .array([.string("identifier"), .string("appPath")])
    ])

    static let deviceLaunchObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "identifier": .object(["type": .string("string")]),
            "bundleID": .object(["type": .string("string")]),
            "startStopped": .object(["type": .string("boolean")]),
            "appPath": .object([
                "type": .string("string"),
                "description": .string("Required for legacy ios-deploy launch; recommended for CoreDevice PID discovery")
            ])
        ]),
        "required": .array([.string("identifier"), .string("bundleID")])
    ])

    static let deviceIdentifierObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "identifier": .object([
                "type": .string("string"),
                "description": .string("CoreDevice UUID")
            ])
        ]),
        "required": .array([.string("identifier")])
    ])

    static let deviceProcessObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "identifier": .object(["type": .string("string")]),
            "processID": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("identifier"), .string("processID")])
    ])

    static let deviceTerminateObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "identifier": .object(["type": .string("string")]),
            "processID": .object(["type": .string("integer")]),
            "force": .object([
                "type": .string("boolean"),
                "description": .string("Use SIGKILL instead of the graceful termination signal")
            ])
        ]),
        "required": .array([.string("identifier"), .string("processID")])
    ])

    static let deviceSignalObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "identifier": .object(["type": .string("string")]),
            "processID": .object(["type": .string("integer")]),
            "signal": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("SIGHUP"), .string("SIGINT"), .string("SIGQUIT"), .string("SIGILL"),
                    .string("SIGABRT"), .string("SIGFPE"), .string("SIGKILL"), .string("SIGSEGV"),
                    .string("SIGPIPE"), .string("SIGALRM"), .string("SIGTERM"), .string("SIGSTOP"),
                    .string("SIGCONT"), .string("SIGUSR1"), .string("SIGUSR2")
                ])
            ])
        ]),
        "required": .array([.string("identifier"), .string("processID"), .string("signal")])
    ])

    static let deviceSysdiagnoseObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "identifier": .object(["type": .string("string")]),
            "destination": .object([
                "type": .string("string"),
                "description": .string("Absolute existing directory or path with an existing parent")
            ]),
            "fullLogs": .object(["type": .string("boolean")])
        ]),
        "required": .array([.string("identifier"), .string("destination")])
    ])

    static let xcodeDiscoverObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Path to an .xcodeproj or .xcworkspace")
            ])
        ]),
        "required": .array([.string("path")])
    ])

    static let xcodeBuildObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object(["type": .string("string")]),
            "scheme": .object(["type": .string("string")]),
            "configuration": .object(["type": .string("string")]),
            "destination": .object(["type": .string("string")]),
            "derivedDataPath": .object([
                "type": .string("string"),
                "description": .string("Optional absolute derived-data directory; build results include discovered app and dSYM artifacts")
            ])
        ]),
        "required": .array([.string("path"), .string("scheme"), .string("destination")])
    ])

    static let xcodeTestObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object(["type": .string("string")]),
            "scheme": .object(["type": .string("string")]),
            "configuration": .object(["type": .string("string")]),
            "destination": .object(["type": .string("string")]),
            "derivedDataPath": .object(["type": .string("string")]),
            "resultBundlePath": .object([
                "type": .string("string"),
                "description": .string("Optional absolute xcresult output path")
            ]),
            "codeSigningAllowed": .object(["type": .string("boolean")])
        ]),
        "required": .array([.string("path"), .string("scheme"), .string("destination")])
    ])

    static let symbolicateObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "binaryPath": .object(["type": .string("string")]),
            "architecture": .object(["type": .string("string")]),
            "address": .object(["type": .string("string")]),
            "loadAddress": .object(["type": .string("string")])
        ]),
        "required": .array([.string("binaryPath"), .string("architecture"), .string("address")])
    ])
}
