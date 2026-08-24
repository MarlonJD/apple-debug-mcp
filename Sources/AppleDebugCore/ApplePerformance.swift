// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum ApplePerformanceError: Error, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case permissionDisabled
    case simulatorNotFound(String)
    case traceNotFound
    case toolUnavailable
    case commandFailed(String)
    case outputTooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Performance trace request is invalid or exceeds the bounded limits."
        case .permissionDisabled:
            return "Performance capture requires an explicit authorized target or Simulator policy grant."
        case .simulatorNotFound(let udid):
            return "Simulator is not in the available inventory: \(udid)"
        case .traceNotFound:
            return "The requested xctrace bundle was not found."
        case .toolUnavailable:
            return "The local xctrace executable was not found."
        case .commandFailed(let message):
            return "xctrace command failed: \(message)"
        case .outputTooLarge:
            return "xctrace command output exceeds the configured limit."
        }
    }
}

public struct ApplePerformanceTraceResult: Codable, Equatable, Sendable {
    public let processID: Int?
    public let simulatorUDID: String?
    public let template: String
    public let durationSeconds: Int
    public let tracePath: String
    public let output: String

    public init(
        processID: Int?,
        simulatorUDID: String?,
        template: String,
        durationSeconds: Int,
        tracePath: String,
        output: String
    ) {
        self.processID = processID
        self.simulatorUDID = simulatorUDID
        self.template = template
        self.durationSeconds = durationSeconds
        self.tracePath = tracePath
        self.output = output
    }
}

public struct ApplePerformanceTraceSummary: Codable, Equatable, Sendable {
    public let templateName: String?
    public let durationSeconds: Double?
    public let startDate: String?
    public let endDate: String?
    public let endReason: String?
    public let processName: String?
    public let processID: Int?
    public let availableSchemas: [String]

    public init(
        templateName: String?,
        durationSeconds: Double?,
        startDate: String?,
        endDate: String?,
        endReason: String?,
        processName: String?,
        processID: Int?,
        availableSchemas: [String]
    ) {
        self.templateName = templateName
        self.durationSeconds = durationSeconds
        self.startDate = startDate
        self.endDate = endDate
        self.endReason = endReason
        self.processName = processName
        self.processID = processID
        self.availableSchemas = availableSchemas
    }
}

public struct ApplePerformanceTraceFrame: Codable, Equatable, Sendable {
    public let name: String?
    public let address: String?
    public let binaryName: String?
    public let binaryUUID: String?
    public let binaryArchitecture: String?
    public let binaryLoadAddress: String?
    public let binaryPath: String?

    public init(
        name: String?,
        address: String?,
        binaryName: String?,
        binaryUUID: String?,
        binaryArchitecture: String?,
        binaryLoadAddress: String?,
        binaryPath: String?
    ) {
        self.name = name
        self.address = address
        self.binaryName = binaryName
        self.binaryUUID = binaryUUID
        self.binaryArchitecture = binaryArchitecture
        self.binaryLoadAddress = binaryLoadAddress
        self.binaryPath = binaryPath
    }
}

public struct ApplePerformanceTraceRow: Codable, Equatable, Sendable {
    public let timeNanoseconds: Int64?
    public let timeFormatted: String?
    public let processName: String?
    public let processID: Int?
    public let threadName: String?
    public let threadID: Int?
    public let core: Int?
    public let state: String?
    public let weightNanoseconds: Int64?
    public let sampleType: String?
    public let stackSummary: String?
    public let addresses: [String]
    public let frames: [ApplePerformanceTraceFrame]
    public let fields: [String: String]

    public init(
        timeNanoseconds: Int64?,
        timeFormatted: String?,
        processName: String?,
        processID: Int?,
        threadName: String?,
        threadID: Int?,
        core: Int?,
        state: String?,
        weightNanoseconds: Int64?,
        sampleType: String?,
        stackSummary: String?,
        addresses: [String],
        frames: [ApplePerformanceTraceFrame],
        fields: [String: String]
    ) {
        self.timeNanoseconds = timeNanoseconds
        self.timeFormatted = timeFormatted
        self.processName = processName
        self.processID = processID
        self.threadName = threadName
        self.threadID = threadID
        self.core = core
        self.state = state
        self.weightNanoseconds = weightNanoseconds
        self.sampleType = sampleType
        self.stackSummary = stackSummary
        self.addresses = addresses
        self.frames = frames
        self.fields = fields
    }
}

public struct ApplePerformanceHotspot: Codable, Equatable, Sendable {
    public let symbol: String
    public let address: String?
    public let binaryName: String?
    public let sampleCount: Int
    public let weightNanoseconds: Int64
    public let percentage: Double

    public init(
        symbol: String,
        address: String?,
        binaryName: String?,
        sampleCount: Int,
        weightNanoseconds: Int64,
        percentage: Double
    ) {
        self.symbol = symbol
        self.address = address
        self.binaryName = binaryName
        self.sampleCount = sampleCount
        self.weightNanoseconds = weightNanoseconds
        self.percentage = percentage
    }
}

public struct ApplePerformanceFlameStack: Codable, Equatable, Sendable {
    public let foldedStack: String
    public let sampleCount: Int
    public let weightNanoseconds: Int64

    public init(foldedStack: String, sampleCount: Int, weightNanoseconds: Int64) {
        self.foldedStack = foldedStack
        self.sampleCount = sampleCount
        self.weightNanoseconds = weightNanoseconds
    }
}

public struct ApplePerformanceSemanticSummary: Codable, Equatable, Sendable {
    public let schema: String
    public let eventCount: Int
    public let uniqueThreadCount: Int
    public let uniqueProcessCount: Int
    public let runningCount: Int
    public let blockedCount: Int
    public let allocationEventCount: Int
    public let allocationBytes: Int64
    public let hitchCount: Int
    public let hitchDurationNanoseconds: Int64
    public let signpostCount: Int
    public let concurrencyTaskCount: Int
    public let concurrencyActorCount: Int
    public let concurrencyContinuationCount: Int

    public init(
        schema: String,
        eventCount: Int,
        uniqueThreadCount: Int,
        uniqueProcessCount: Int,
        runningCount: Int,
        blockedCount: Int,
        allocationEventCount: Int,
        allocationBytes: Int64,
        hitchCount: Int,
        hitchDurationNanoseconds: Int64,
        signpostCount: Int,
        concurrencyTaskCount: Int,
        concurrencyActorCount: Int,
        concurrencyContinuationCount: Int
    ) {
        self.schema = schema
        self.eventCount = eventCount
        self.uniqueThreadCount = uniqueThreadCount
        self.uniqueProcessCount = uniqueProcessCount
        self.runningCount = runningCount
        self.blockedCount = blockedCount
        self.allocationEventCount = allocationEventCount
        self.allocationBytes = allocationBytes
        self.hitchCount = hitchCount
        self.hitchDurationNanoseconds = hitchDurationNanoseconds
        self.signpostCount = signpostCount
        self.concurrencyTaskCount = concurrencyTaskCount
        self.concurrencyActorCount = concurrencyActorCount
        self.concurrencyContinuationCount = concurrencyContinuationCount
    }
}

public enum ApplePerformanceSemanticDomain: String, Codable, CaseIterable, Sendable {
    case timeProfile = "time-profile"
    case allocations
    case systemTrace = "system-trace"
    case powerEnergy = "power-energy"
    case animation
    case signposts
    case swiftConcurrency = "swift-concurrency"
    case generic
}

public struct ApplePerformanceTemplateSemanticReport: Codable, Equatable, Sendable {
    public let templateName: String?
    public let schema: String
    public let domain: ApplePerformanceSemanticDomain
    public let eventCount: Int
    public let uniqueThreadCount: Int
    public let uniqueProcessCount: Int
    public let counts: [String: Int64]
    public let durationsNanoseconds: [String: Int64]
    public let numericTotals: [String: Double]
    public let notes: [String]

    public init(
        templateName: String?,
        schema: String,
        domain: ApplePerformanceSemanticDomain,
        eventCount: Int,
        uniqueThreadCount: Int,
        uniqueProcessCount: Int,
        counts: [String: Int64],
        durationsNanoseconds: [String: Int64],
        numericTotals: [String: Double],
        notes: [String]
    ) {
        self.templateName = templateName
        self.schema = schema
        self.domain = domain
        self.eventCount = eventCount
        self.uniqueThreadCount = uniqueThreadCount
        self.uniqueProcessCount = uniqueProcessCount
        self.counts = counts
        self.durationsNanoseconds = durationsNanoseconds
        self.numericTotals = numericTotals
        self.notes = notes
    }
}

public struct ApplePerformanceAnalysisResult: Codable, Equatable, Sendable {
    public let tracePath: String
    public let schema: String
    public let summary: ApplePerformanceTraceSummary
    public let sampleCount: Int
    public let rows: [ApplePerformanceTraceRow]
    public let hotspots: [ApplePerformanceHotspot]
    public let flameStacks: [ApplePerformanceFlameStack]
    public let semantic: ApplePerformanceSemanticSummary
    public let templateSemantic: ApplePerformanceTemplateSemanticReport

    public init(
        tracePath: String,
        schema: String,
        summary: ApplePerformanceTraceSummary,
        sampleCount: Int,
        rows: [ApplePerformanceTraceRow],
        hotspots: [ApplePerformanceHotspot],
        flameStacks: [ApplePerformanceFlameStack],
        semantic: ApplePerformanceSemanticSummary,
        templateSemantic: ApplePerformanceTemplateSemanticReport
    ) {
        self.tracePath = tracePath
        self.schema = schema
        self.summary = summary
        self.sampleCount = sampleCount
        self.rows = rows
        self.hotspots = hotspots
        self.flameStacks = flameStacks
        self.semantic = semantic
        self.templateSemantic = templateSemantic
    }
}

public enum ApplePerformanceService {
    public static let swiftConcurrencySchemas = [
        "swift-task-state", "swift-actor-count", "swift-task-cancellation-event",
        "swift-total-task-count", "swift-actor-lifetime", "swift-actor-execution",
        "swift-task-creation-event", "swift-actor-queue-size", "swift-task-relationship",
        "swift-alive-task-count", "swift-task-lifetime", "swift-running-task-count"
    ]

    private static let templates = [
        "Time Profiler", "Allocations", "System Trace", "Power Profiler", "Animation Hitches",
        "Swift Concurrency", "Processor Trace", "CPU Profiler", "Leaks", "Network",
        "File Activity", "Game Performance"
    ]
    private static let analysisSchemas = [
        "time-profile", "time-sample", "allocations", "allocation", "os-signpost", "os-log",
        "animation-hitch", "animation-hitches", "power", "energy", "core-animation",
        "swift-concurrency", "thread-info", "process-info", "signpost"
    ] + swiftConcurrencySchemas
    private static let maximumExportSize = 32 * 1024 * 1024

    public static func record(
        processID: Int?,
        simulatorUDID: String?,
        template: String,
        durationSeconds: Int,
        outputPath: String
    ) throws -> ApplePerformanceTraceResult {
        guard (processID == nil) != (simulatorUDID == nil),
              templates.contains(template),
              (1...60).contains(durationSeconds),
              !outputPath.isEmpty, outputPath.utf8.count <= 4_096,
              !outputPath.contains("\0"),
              outputPath.hasSuffix(".trace"),
              URL(fileURLWithPath: outputPath).path.hasPrefix("/"),
              !FileManager.default.fileExists(atPath: outputPath) else {
            throw ApplePerformanceError.invalidRequest
        }

        var arguments = [
            "record",
            "--template", template,
            "--output", outputPath,
            "--time-limit", "\(durationSeconds)s",
            "--no-prompt"
        ]
        if let processID {
            try DebugPolicy.validateAttach(processID: processID)
            arguments += ["--attach", String(processID)]
        } else if let simulatorUDID {
            guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION"] == "1" else {
                throw ApplePerformanceError.permissionDisabled
            }
            guard try SimulatorService.list().contains(where: { $0.udid == simulatorUDID }) else {
                throw ApplePerformanceError.simulatorNotFound(simulatorUDID)
            }
            arguments += ["--device", simulatorUDID, "--all-processes"]
        }
        guard let xctracePath = ToolchainProbe.path(for: "xctrace") else {
            throw ApplePerformanceError.toolUnavailable
        }
        let result: AppleProcessResult
        do {
            result = try AppleProcessRunner.run(
                executable: xctracePath,
                arguments: arguments,
                maximumOutputSize: 8 * 1024 * 1024
            )
        } catch AppleProcessRunnerError.outputTooLarge {
            throw ApplePerformanceError.outputTooLarge
        } catch AppleProcessRunnerError.launchFailed(let message) {
            throw ApplePerformanceError.commandFailed(message)
        } catch {
            throw ApplePerformanceError.commandFailed(error.localizedDescription)
        }
        guard result.terminationStatus == 0 else {
            let message = String(decoding: result.stderr, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ApplePerformanceError.commandFailed(message.isEmpty ? "xctrace failed." : message)
        }
        guard FileManager.default.fileExists(atPath: outputPath) else {
            throw ApplePerformanceError.commandFailed("xctrace completed without producing a trace file.")
        }
        return ApplePerformanceTraceResult(
            processID: processID,
            simulatorUDID: simulatorUDID,
            template: template,
            durationSeconds: durationSeconds,
            tracePath: outputPath,
            output: String(decoding: result.stdout, as: UTF8.self)
        )
    }

    public static func analyze(
        tracePath: String,
        schema: String = "time-profile",
        maximumRows: Int = 5_000,
        includeRows: Bool = false
    ) throws -> ApplePerformanceAnalysisResult {
        guard !tracePath.isEmpty,
              tracePath.utf8.count <= 4_096,
              !tracePath.contains("\0"),
              tracePath.hasSuffix(".trace"),
              URL(fileURLWithPath: tracePath).path.hasPrefix("/"),
              analysisSchemas.contains(schema),
              (1...5_000).contains(maximumRows) else {
            throw ApplePerformanceError.invalidRequest
        }
        guard isTraceDirectory(tracePath) else {
            throw ApplePerformanceError.traceNotFound
        }
        guard ToolchainProbe.path(for: "xctrace") != nil else {
            throw ApplePerformanceError.toolUnavailable
        }

        let tocData = try export(
            tracePath: tracePath,
            arguments: ["--toc"]
        )
        let summary = try PerformanceTraceTOCParser.parse(tocData)
        let querySchemas: [String]
        if schema == "swift-concurrency" {
            let availableSchemas = Set(summary.availableSchemas)
            querySchemas = swiftConcurrencySchemas.filter { availableSchemas.contains($0) }
        } else {
            querySchemas = [schema]
        }
        var rows: [ApplePerformanceTraceRow] = []
        let perSchemaLimit = querySchemas.isEmpty ? 0 : max(1, maximumRows / querySchemas.count)
        for querySchema in querySchemas {
            let remaining = maximumRows - rows.count
            guard remaining > 0 else { break }
            let queryData = try export(
                tracePath: tracePath,
                arguments: [
                    "--xpath",
                    "/trace-toc/run[@number=\"1\"]/data/table[@schema=\"\(querySchema)\"]"
                ]
            )
            rows.append(contentsOf: try PerformanceTraceRowsParser.parse(queryData, maximumRows: min(remaining, perSchemaLimit)))
        }
        let analysis = analyzeRows(rows)
        let semantic = semanticSummary(schema: schema, rows: rows)
        let templateSemantic = buildTemplateSemanticReport(
            templateName: summary.templateName,
            schema: schema,
            rows: rows
        )
        return ApplePerformanceAnalysisResult(
            tracePath: tracePath,
            schema: schema,
            summary: summary,
            sampleCount: rows.count,
            rows: includeRows ? rows : [],
            hotspots: analysis.hotspots,
            flameStacks: analysis.flameStacks,
            semantic: semantic,
            templateSemantic: templateSemantic
        )
    }

    public static func buildTemplateSemanticReport(
        templateName: String?,
        schema: String,
        rows: [ApplePerformanceTraceRow]
    ) -> ApplePerformanceTemplateSemanticReport {
        let domain = semanticDomain(templateName: templateName, schema: schema)
        let threadCount = Set(rows.compactMap(\.threadID)).count
        let processCount = Set(rows.compactMap(\.processID)).count
        var counts: [String: Int64] = [
            "events": Int64(rows.count),
            "threads": Int64(threadCount),
            "processes": Int64(processCount)
        ]
        let runningCount = rows.filter { $0.state?.localizedCaseInsensitiveCompare("Running") == .orderedSame }.count
        let blockedCount = rows.filter { $0.state?.localizedCaseInsensitiveCompare("Blocked") == .orderedSame }.count
        if runningCount > 0 { counts["running"] = Int64(runningCount) }
        if blockedCount > 0 { counts["blocked"] = Int64(blockedCount) }

        let taskRows = rows.filter { hasSemanticField($0.fields, fragments: ["task"], excluding: ["state", "priority", "count"]) }
        let actorRows = rows.filter { hasSemanticField($0.fields, fragments: ["actor", "executor"], excluding: ["count", "queue"]) }
        let continuationRows = rows.filter { row in
            hasSemanticField(row.fields, fragments: ["continuation"], excluding: []) ||
                row.fields.contains { key, value in
                    key.localizedCaseInsensitiveContains("state") && value.localizedCaseInsensitiveContains("continuation")
                }
        }
        if domain == .allocations { counts["allocations"] = Int64(rows.count) }
        if domain == .animation { counts["hitches"] = Int64(rows.count) }
        if domain == .signposts { counts["signposts"] = Int64(rows.count) }
        if domain == .powerEnergy { counts["power-energy-samples"] = Int64(rows.count) }
        if domain == .swiftConcurrency {
            counts["tasks"] = Int64(taskRows.count)
            counts["actors"] = Int64(actorRows.count)
            counts["continuations"] = Int64(continuationRows.count)
        }

        var durations: [String: Int64] = [:]
        var numericTotals: [String: Double] = [:]
        for row in rows {
            for (key, value) in row.fields where !key.hasSuffix(".fmt") {
                let lowerKey = key.localizedLowercase
                guard let number = numericValue(value) else { continue }
                if lowerKey.contains("duration") || lowerKey.contains("latency") || lowerKey.contains("interval") {
                    durations[durationName(for: domain, key: lowerKey), default: 0] += Int64(number)
                }
                if isSemanticMeasurement(domain: domain, key: lowerKey) {
                    numericTotals[key, default: 0] += number
                }
            }
        }
        if let totalDuration = durations["durationNanoseconds"], domain == .animation {
            durations["hitchDurationNanoseconds"] = totalDuration
        }
        if let totalDuration = durations["durationNanoseconds"], domain == .signposts {
            durations["signpostDurationNanoseconds"] = totalDuration
        }
        let notes: [String]
        if rows.isEmpty {
            notes = ["The selected public xctrace schema exported no rows; the report contains no inferred metrics."]
        } else {
            notes = [
                "Counts and numeric totals are reconstructed from public xctrace XML rows; numericTotals preserve the source field units.",
                "Private framework/runtime state and undocumented Instruments databases are not accessed."
            ]
        }
        return ApplePerformanceTemplateSemanticReport(
            templateName: templateName,
            schema: schema,
            domain: domain,
            eventCount: rows.count,
            uniqueThreadCount: threadCount,
            uniqueProcessCount: processCount,
            counts: counts,
            durationsNanoseconds: durations,
            numericTotals: numericTotals,
            notes: notes
        )
    }

    private static func export(tracePath: String, arguments: [String]) throws -> Data {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-xctrace-\(UUID().uuidString).xml")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        guard let xctracePath = ToolchainProbe.path(for: "xctrace") else {
            throw ApplePerformanceError.toolUnavailable
        }
        let result: AppleProcessResult
        do {
            result = try AppleProcessRunner.run(
                executable: xctracePath,
                arguments: ["export", "--input", tracePath] + arguments + ["--output", outputURL.path],
                maximumOutputSize: 512 * 1024
            )
        } catch AppleProcessRunnerError.outputTooLarge {
            throw ApplePerformanceError.outputTooLarge
        } catch AppleProcessRunnerError.launchFailed(let message) {
            throw ApplePerformanceError.commandFailed(message)
        } catch {
            throw ApplePerformanceError.commandFailed(error.localizedDescription)
        }
        guard result.terminationStatus == 0 else {
            let message = String(decoding: result.stderr, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ApplePerformanceError.commandFailed(message.isEmpty ? "xctrace export failed." : message)
        }
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw ApplePerformanceError.commandFailed("xctrace export did not produce XML output.")
        }
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        } catch {
            throw ApplePerformanceError.commandFailed(error.localizedDescription)
        }
        guard let fileSize = attributes[.size] as? NSNumber,
              fileSize.intValue <= maximumExportSize else {
            throw ApplePerformanceError.outputTooLarge
        }
        do {
            return try Data(contentsOf: outputURL)
        } catch {
            throw ApplePerformanceError.commandFailed(error.localizedDescription)
        }
    }

    private static func isTraceDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static func analyzeRows(
        _ rows: [ApplePerformanceTraceRow]
    ) -> (hotspots: [ApplePerformanceHotspot], flameStacks: [ApplePerformanceFlameStack]) {
        var hotspotValues: [String: MutableHotspot] = [:]
        var flameValues: [String: MutableFlameStack] = [:]
        var totalWeight: Int64 = 0
        for row in rows {
            let weight = row.weightNanoseconds ?? 1_000_000
            totalWeight += max(0, weight)
            let frames = row.frames.map { frame in
                frame.name ?? frame.address ?? "<unknown>"
            }
            let fallback = row.fields["symbol"] ?? row.fields["class"] ?? row.fields["category"] ??
                row.addresses.first ?? row.stackSummary ?? "<unknown>"
            let stack = frames.isEmpty ? [fallback] : frames
            let top = stack[0]
            let key = "\(top)\u{0000}\(row.frames.first?.binaryName ?? "")"
            var hotspot = hotspotValues[key] ?? MutableHotspot(
                symbol: top,
                address: row.frames.first?.address ?? row.addresses.first,
                binaryName: row.frames.first?.binaryName,
                sampleCount: 0,
                weightNanoseconds: 0
            )
            hotspot.sampleCount += 1
            hotspot.weightNanoseconds += weight
            hotspotValues[key] = hotspot

            let folded = stack.reversed().joined(separator: ";")
            var flame = flameValues[folded] ?? MutableFlameStack(sampleCount: 0, weightNanoseconds: 0)
            flame.sampleCount += 1
            flame.weightNanoseconds += weight
            flameValues[folded] = flame
        }
        let denominator = max(1, totalWeight)
        let hotspots = hotspotValues.values
            .map { value in
                ApplePerformanceHotspot(
                    symbol: value.symbol,
                    address: value.address,
                    binaryName: value.binaryName,
                    sampleCount: value.sampleCount,
                    weightNanoseconds: value.weightNanoseconds,
                    percentage: Double(value.weightNanoseconds) * 100 / Double(denominator)
                )
            }
            .sorted {
                if $0.weightNanoseconds != $1.weightNanoseconds {
                    return $0.weightNanoseconds > $1.weightNanoseconds
                }
                return $0.symbol < $1.symbol
            }
            .prefix(100)
            .map { $0 }
        let flameStacks = flameValues.map { key, value in
            ApplePerformanceFlameStack(
                foldedStack: key,
                sampleCount: value.sampleCount,
                weightNanoseconds: value.weightNanoseconds
            )
        }.sorted {
            if $0.weightNanoseconds != $1.weightNanoseconds {
                return $0.weightNanoseconds > $1.weightNanoseconds
            }
            return $0.foldedStack < $1.foldedStack
        }.prefix(10_000).map { $0 }
        return (hotspots, flameStacks)
    }

    private static func semanticSummary(schema: String, rows: [ApplePerformanceTraceRow]) -> ApplePerformanceSemanticSummary {
        let threadIDs = Set(rows.compactMap(\.threadID))
        let processIDs = Set(rows.compactMap(\.processID))
        let runningCount = rows.filter { $0.state?.localizedCaseInsensitiveCompare("Running") == .orderedSame }.count
        let blockedCount = rows.filter { $0.state?.localizedCaseInsensitiveCompare("Blocked") == .orderedSame }.count
        let allocationRows = rows.filter { row in
            schema.localizedCaseInsensitiveContains("alloc") || row.fields.keys.contains { $0.localizedCaseInsensitiveContains("alloc") }
        }
        let allocationBytes = allocationRows.reduce(Int64(0)) { total, row in
            total + row.fields.reduce(Int64(0)) { value, pair in
                guard pair.key.localizedCaseInsensitiveContains("size") || pair.key.localizedCaseInsensitiveContains("bytes") else { return value }
                return value + Int64(Double(pair.value) ?? 0)
            }
        }
        let hitchRows = rows.filter { schema.localizedCaseInsensitiveContains("hitch") || $0.fields.keys.contains { $0.localizedCaseInsensitiveContains("hitch") } }
        let hitchDuration = hitchRows.reduce(Int64(0)) { total, row in
            total + row.fields.reduce(Int64(0)) { value, pair in
                guard pair.key.localizedCaseInsensitiveContains("duration") || pair.key.localizedCaseInsensitiveContains("latency") else { return value }
                return value + parseDuration(pair.value)
            }
        }
        let signpostCount = rows.filter { schema.localizedCaseInsensitiveContains("signpost") || $0.fields.keys.contains { $0.localizedCaseInsensitiveContains("signpost") } }.count
        let concurrencyRows = rows.filter { schema.localizedCaseInsensitiveContains("concurrency") || $0.fields.keys.contains { key in
            let value = key.localizedLowercase
            return value.contains("task") || value.contains("actor") || value.contains("continuation")
        }}
        let taskCount = concurrencyRows.filter { $0.fields.keys.contains { $0.localizedCaseInsensitiveContains("task") } }.count
        let actorCount = concurrencyRows.filter { $0.fields.keys.contains { $0.localizedCaseInsensitiveContains("actor") } }.count
        let continuationCount = concurrencyRows.filter { row in
            row.fields.keys.contains { $0.localizedCaseInsensitiveContains("continuation") } ||
                row.fields.contains { key, value in
                    key.localizedCaseInsensitiveContains("state") && value.localizedCaseInsensitiveContains("continuation")
                }
        }.count
        return ApplePerformanceSemanticSummary(
            schema: schema,
            eventCount: rows.count,
            uniqueThreadCount: threadIDs.count,
            uniqueProcessCount: processIDs.count,
            runningCount: runningCount,
            blockedCount: blockedCount,
            allocationEventCount: allocationRows.count,
            allocationBytes: allocationBytes,
            hitchCount: hitchRows.count,
            hitchDurationNanoseconds: hitchDuration,
            signpostCount: signpostCount,
            concurrencyTaskCount: taskCount,
            concurrencyActorCount: actorCount,
            concurrencyContinuationCount: continuationCount
        )
    }

    private static func semanticDomain(templateName: String?, schema: String) -> ApplePerformanceSemanticDomain {
        let value = "\(templateName ?? "") \(schema)".localizedLowercase
        if value.contains("swift") || value.contains("concurr") { return .swiftConcurrency }
        if value.contains("alloc") { return .allocations }
        if value.contains("system trace") || value.contains("system-trace") { return .systemTrace }
        if value.contains("power") || value.contains("energy") { return .powerEnergy }
        if value.contains("hitch") || value.contains("core-animation") || value.contains("animation") { return .animation }
        if value.contains("signpost") { return .signposts }
        if schema == "time-profile" { return .timeProfile }
        if schema == "time-sample" || schema == "thread-info" || schema == "process-info" { return .systemTrace }
        return .generic
    }

    private static func hasSemanticField(
        _ fields: [String: String],
        fragments: [String],
        excluding: [String]
    ) -> Bool {
        fields.keys.contains { key in
            guard !key.hasSuffix(".fmt") else { return false }
            let lower = key.localizedLowercase
            return fragments.contains(where: { lower.contains($0) }) &&
                !excluding.contains(where: { lower.contains($0) })
        }
    }

    private static func numericValue(_ value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: ""))
    }

    private static func durationName(for domain: ApplePerformanceSemanticDomain, key: String) -> String {
        _ = key
        switch domain {
        case .animation:
            return "durationNanoseconds"
        case .signposts:
            return "durationNanoseconds"
        default:
            return "durationNanoseconds"
        }
    }

    private static func isSemanticMeasurement(domain: ApplePerformanceSemanticDomain, key: String) -> Bool {
        switch domain {
        case .allocations:
            return key.contains("alloc") || key.contains("size") || key.contains("bytes")
        case .powerEnergy:
            return key.contains("power") || key.contains("energy") || key.contains("watt") ||
                key.contains("joule") || key.contains("charge") || key.contains("thermal") ||
                key.contains("cpu") || key.contains("gpu")
        case .animation:
            return key.contains("hitch") || key.contains("frame") || key.contains("jank") ||
                key.contains("duration") || key.contains("latency") || key.contains("interval")
        case .signposts:
            return key.contains("signpost") || key.contains("duration") || key.contains("interval")
        case .swiftConcurrency:
            return key.contains("duration") || key.contains("latency")
        case .timeProfile, .systemTrace, .generic:
            return key.contains("duration") || key.contains("weight") || key.contains("latency")
        }
    }

    private static func parseDuration(_ value: String) -> Int64 {
        let normalized = value.replacingOccurrences(of: " ", with: "")
        if let number = Double(normalized) { return Int64(number) }
        if normalized.hasSuffix("ms"), let number = Double(normalized.dropLast(2)) { return Int64(number * 1_000_000) }
        if normalized.hasSuffix("us"), let number = Double(normalized.dropLast(2)) { return Int64(number * 1_000) }
        if normalized.hasSuffix("s"), let number = Double(normalized.dropLast()) { return Int64(number * 1_000_000_000) }
        return 0
    }

    private struct MutableHotspot {
        let symbol: String
        let address: String?
        let binaryName: String?
        var sampleCount: Int
        var weightNanoseconds: Int64
    }

    private struct MutableFlameStack {
        var sampleCount: Int
        var weightNanoseconds: Int64
    }
}

private enum PerformanceXMLParserError: Error {
    case malformed(String)
}

private final class PerformanceTraceTOCParser: NSObject, XMLParserDelegate {
    private var elements: [String] = []
    private var textElement: String?
    private var text = ""
    private var values: [String: String] = [:]
    private var processName: String?
    private var processID: Int?
    private var schemas = Set<String>()

    static func parse(_ data: Data) throws -> ApplePerformanceTraceSummary {
        let delegate = PerformanceTraceTOCParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw PerformanceXMLParserError.malformed(parser.parserError?.localizedDescription ?? "invalid xctrace TOC XML")
        }
        return ApplePerformanceTraceSummary(
            templateName: delegate.values["template-name"],
            durationSeconds: delegate.values["duration"].flatMap(Double.init),
            startDate: delegate.values["start-date"],
            endDate: delegate.values["end-date"],
            endReason: delegate.values["end-reason"],
            processName: delegate.processName,
            processID: delegate.processID,
            availableSchemas: delegate.schemas.sorted()
        )
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        elements.append(elementName)
        if elementName == "table", let schema = attributeDict["schema"] {
            schemas.insert(schema)
        }
        if elementName == "process", elements.dropLast().contains("target") {
            processName = attributeDict["name"]
            processID = attributeDict["pid"].flatMap(Int.init)
        }
        if ["start-date", "end-date", "duration", "end-reason", "template-name"].contains(elementName) {
            textElement = elementName
            text = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard textElement != nil else { return }
        text += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if textElement == elementName {
            values[elementName] = text.trimmingCharacters(in: .whitespacesAndNewlines)
            textElement = nil
            text = ""
        }
        _ = elements.popLast()
    }
}

private final class PerformanceTraceRowsParser: NSObject, XMLParserDelegate {
    private struct MutableFrame {
        var name: String?
        var address: String?
        var binaryName: String?
        var binaryUUID: String?
        var binaryArchitecture: String?
        var binaryLoadAddress: String?
        var binaryPath: String?
    }

    private struct MutableRow {
        var timeNanoseconds: Int64?
        var timeFormatted: String?
        var processName: String?
        var processID: Int?
        var threadName: String?
        var threadID: Int?
        var core: Int?
        var state: String?
        var weightNanoseconds: Int64?
        var sampleType: String?
        var stackSummary: String?
        var addresses: [String] = []
        var frames: [MutableFrame] = []
        var fields: [String: String] = [:]
    }

    private let maximumRows: Int
    private var rows: [ApplePerformanceTraceRow] = []
    private var currentRow: MutableRow?
    private var currentFrame: MutableFrame?
    private var textElement: String?
    private var text = ""
    private var didHitLimit = false
    private var referenceValues: [String: String] = [:]

    private init(maximumRows: Int) {
        self.maximumRows = maximumRows
    }

    static func parse(_ data: Data, maximumRows: Int) throws -> [ApplePerformanceTraceRow] {
        let delegate = PerformanceTraceRowsParser(maximumRows: maximumRows)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        _ = parser.parse()
        if !delegate.didHitLimit, let error = parser.parserError {
            throw PerformanceXMLParserError.malformed(error.localizedDescription)
        }
        return delegate.rows
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if let id = attributeDict["id"], let formatted = attributeDict["fmt"] {
            referenceValues[id] = formatted
        }
        switch elementName {
        case "row":
            currentRow = MutableRow(
                timeNanoseconds: nil,
                timeFormatted: nil,
                processName: nil,
                processID: nil,
                threadName: nil,
                threadID: nil,
                core: nil,
                state: nil,
                weightNanoseconds: nil,
                sampleType: nil,
                stackSummary: nil
            )
        case "thread":
            if var row = currentRow, let formatted = attributeDict["fmt"], attributeDict["ref"] == nil {
                row.threadName = formatted
                currentRow = row
            }
        case "process":
            if var row = currentRow, let formatted = attributeDict["fmt"], attributeDict["ref"] == nil {
                let parsed = Self.parseNameAndID(formatted)
                row.processName = parsed.name
                row.processID = parsed.id
                currentRow = row
            }
        case "tagged-backtrace":
            if var row = currentRow, let formatted = attributeDict["fmt"], attributeDict["ref"] == nil {
                row.stackSummary = formatted
                currentRow = row
            }
        case "frame":
            if currentRow != nil, attributeDict["ref"] == nil {
                currentFrame = MutableFrame(
                    name: attributeDict["name"],
                    address: attributeDict["addr"],
                    binaryName: nil,
                    binaryUUID: nil,
                    binaryArchitecture: nil,
                    binaryLoadAddress: nil,
                    binaryPath: nil
                )
            }
        case "binary":
            if var frame = currentFrame, attributeDict["ref"] == nil {
                frame.binaryName = attributeDict["name"]
                frame.binaryUUID = attributeDict["UUID"]
                frame.binaryArchitecture = attributeDict["arch"]
                frame.binaryLoadAddress = attributeDict["load-addr"]
                frame.binaryPath = attributeDict["path"]
                currentFrame = frame
            }
        default:
            break
        }
        if ["sample-time", "tid", "core", "thread-state", "weight", "time-sample-kind", "text-addresses", "text-address"].contains(elementName),
           attributeDict["ref"] == nil {
            textElement = elementName
            text = ""
            if elementName == "sample-time" {
                currentRow?.timeFormatted = attributeDict["fmt"]
            }
            if elementName == "text-address" {
                appendAddress(attributeDict["fmt"])
            }
        } else if currentRow != nil,
                  attributeDict["ref"] == nil,
                  !["row", "thread", "process", "tagged-backtrace", "backtrace", "frame", "binary", "sentinel"].contains(elementName) {
            textElement = elementName
            text = ""
            if let fmt = attributeDict["fmt"] {
                currentRow?.fields["\(elementName).fmt"] = fmt
            }
        } else if let ref = attributeDict["ref"],
                  let value = referenceValues[ref],
                  currentRow != nil,
                  !["row", "thread", "process", "tagged-backtrace", "backtrace", "frame", "binary", "sentinel"].contains(elementName) {
            currentRow?.fields[elementName] = value
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard textElement != nil else { return }
        text += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if textElement == elementName {
            applyText(elementName)
            textElement = nil
            text = ""
        }
        if elementName == "frame", let frame = currentFrame {
            currentRow?.frames.append(frame)
            currentFrame = nil
        }
        if elementName == "row", let row = currentRow {
            rows.append(
                ApplePerformanceTraceRow(
                    timeNanoseconds: row.timeNanoseconds,
                    timeFormatted: row.timeFormatted,
                    processName: row.processName,
                    processID: row.processID,
                    threadName: row.threadName,
                    threadID: row.threadID,
                    core: row.core,
                    state: row.state,
                    weightNanoseconds: row.weightNanoseconds,
                    sampleType: row.sampleType,
                    stackSummary: row.stackSummary,
                    addresses: row.addresses,
                    frames: row.frames.map { frame in
                        ApplePerformanceTraceFrame(
                            name: frame.name,
                            address: frame.address,
                            binaryName: frame.binaryName,
                            binaryUUID: frame.binaryUUID,
                            binaryArchitecture: frame.binaryArchitecture,
                            binaryLoadAddress: frame.binaryLoadAddress,
                            binaryPath: frame.binaryPath
                        )
                    },
                    fields: row.fields
                )
            )
            currentRow = nil
            if rows.count >= maximumRows {
                didHitLimit = true
                parser.abortParsing()
            }
        }
    }

    private func applyText(_ elementName: String) {
        guard var row = currentRow else { return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty { row.fields[elementName] = value }
        switch elementName {
        case "sample-time":
            row.timeNanoseconds = Int64(value)
        case "tid":
            row.threadID = Self.parseInteger(value)
        case "core":
            row.core = Self.parseInteger(value)
        case "thread-state":
            row.state = value.isEmpty ? nil : value
        case "weight":
            row.weightNanoseconds = Int64(value)
        case "time-sample-kind":
            row.sampleType = value.isEmpty ? nil : value
        case "text-addresses":
            for token in value.split(whereSeparator: { $0 == " " || $0 == "\t" }) {
                if let decimal = UInt64(token), decimal != 0 {
                    let address = "0x\(String(decimal, radix: 16))"
                    if !row.addresses.contains(address) {
                        row.addresses.append(address)
                    }
                }
            }
        default:
            break
        }
        currentRow = row
    }

    private func appendAddress(_ value: String?) {
        guard var row = currentRow, let value, !value.isEmpty, value != "TODO", !row.addresses.contains(value) else {
            return
        }
        row.addresses.append(value)
        currentRow = row
    }

    private static func parseNameAndID(_ value: String) -> (name: String, id: Int?) {
        guard let range = value.range(of: " (", options: .backwards), value.hasSuffix(")"),
              let id = Int(value[value.index(after: range.lowerBound)..<value.index(before: value.endIndex)]) else {
            return (value, nil)
        }
        return (String(value[..<range.lowerBound]), id)
    }

    private static func parseInteger(_ value: String) -> Int? {
        if value.hasPrefix("0x") { return Int(value.dropFirst(2), radix: 16) }
        return Int(value)
    }
}
