// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct SwiftConcurrencyNode: Codable, Equatable, Sendable {
    public let id: String
    public let kind: String
    public let label: String
    public let eventCount: Int

    public init(id: String, kind: String, label: String, eventCount: Int) {
        self.id = id
        self.kind = kind
        self.label = label
        self.eventCount = eventCount
    }
}

public struct SwiftConcurrencyEdge: Codable, Equatable, Sendable {
    public let from: String
    public let to: String
    public let kind: String

    public init(from: String, to: String, kind: String) {
        self.from = from
        self.to = to
        self.kind = kind
    }
}

public struct SwiftConcurrencyGraph: Codable, Equatable, Sendable {
    public let tracePath: String
    public let liveDataAvailable: Bool
    public let sampleCount: Int
    public let nodes: [SwiftConcurrencyNode]
    public let edges: [SwiftConcurrencyEdge]
    public let notes: [String]

    public init(tracePath: String, liveDataAvailable: Bool, sampleCount: Int, nodes: [SwiftConcurrencyNode], edges: [SwiftConcurrencyEdge], notes: [String]) {
        self.tracePath = tracePath
        self.liveDataAvailable = liveDataAvailable
        self.sampleCount = sampleCount
        self.nodes = nodes
        self.edges = edges
        self.notes = notes
    }
}

public enum AppleSwiftConcurrencyGraphService {
    public static func analyze(tracePath: String, maximumRows: Int = 5_000) throws -> SwiftConcurrencyGraph {
        let report = try ApplePerformanceService.analyze(
            tracePath: tracePath,
            schema: "swift-concurrency",
            maximumRows: maximumRows,
            includeRows: true
        )
        return build(tracePath: tracePath, rows: report.rows)
    }

    public static func build(tracePath: String, rows: [ApplePerformanceTraceRow]) -> SwiftConcurrencyGraph {
        var nodeCounts: [String: (kind: String, label: String, count: Int)] = [:]
        var edgeSet = Set<String>()
        var edges: [SwiftConcurrencyEdge] = []
        for row in rows {
            let fields = row.fields
            let task = taskValue(fields)
            let actor = actorValue(fields)
            let continuation = continuationValue(fields, task: task)
            let parentTask = value(fields, keys: ["parent-task", "parent-task-id"])
            let childTask = value(fields, keys: ["child-task", "child-task-id"])
            var didAddGraphNode = false
            if let task, !task.isEmpty {
                addNode(kind: "task", label: task, counts: &nodeCounts)
                didAddGraphNode = true
            }
            if let actor, !actor.isEmpty {
                addNode(kind: "actor", label: actor, counts: &nodeCounts)
                didAddGraphNode = true
            }
            if let continuation, !continuation.isEmpty {
                addNode(kind: "continuation", label: continuation, counts: &nodeCounts)
                didAddGraphNode = true
            }
            if !didAddGraphNode,
               let eventNode = row.threadName ?? row.sampleType,
               !eventNode.isEmpty {
                addNode(kind: "event", label: eventNode, counts: &nodeCounts)
            }
            if let task, let actor {
                addEdge(from: nodeID(kind: "actor", label: actor), to: nodeID(kind: "task", label: task), kind: "executes", set: &edgeSet, edges: &edges)
            }
            if let task, let continuation {
                addEdge(from: nodeID(kind: "task", label: task), to: nodeID(kind: "continuation", label: continuation), kind: "awaits", set: &edgeSet, edges: &edges)
            }
            if let parentTask, let childTask {
                addNode(kind: "task", label: parentTask, counts: &nodeCounts)
                addNode(kind: "task", label: childTask, counts: &nodeCounts)
                addEdge(from: nodeID(kind: "task", label: parentTask), to: nodeID(kind: "task", label: childTask), kind: "child", set: &edgeSet, edges: &edges)
            }
        }
        let nodes = nodeCounts.map { id, value in
            SwiftConcurrencyNode(id: id, kind: value.kind, label: value.label, eventCount: value.count)
        }.sorted { $0.id < $1.id }
        let liveDataAvailable = !rows.isEmpty && !nodes.isEmpty
        return SwiftConcurrencyGraph(
            tracePath: tracePath,
            liveDataAvailable: liveDataAvailable,
            sampleCount: rows.count,
            nodes: nodes,
            edges: edges.sorted {
                if $0.from != $1.from { return $0.from < $1.from }
                if $0.to != $1.to { return $0.to < $1.to }
                return $0.kind < $1.kind
            },
            notes: rows.isEmpty
                ? ["The trace contains no exported swift-concurrency rows; capture the Swift Concurrency xctrace template around an async workload."]
                : !liveDataAvailable
                    ? ["The trace exported rows but no task, actor, executor, or continuation fields; the public xctrace schema may have changed."]
                : ["Graph nodes and edges are reconstructed from the public xctrace swift-concurrency export; private runtime task state is not accessed."]
        )
    }

    private static func addNode(
        kind: String,
        label: String,
        counts: inout [String: (kind: String, label: String, count: Int)]
    ) {
        let id = nodeID(kind: kind, label: label)
        var existing = counts[id] ?? (kind, label, 0)
        existing.count += 1
        counts[id] = existing
    }

    private static func nodeID(kind: String, label: String) -> String {
        "\(kind):\(label)"
    }

    private static func taskValue(_ fields: [String: String]) -> String? {
        value(fields, keys: ["task", "swift-task-id", "swift-task"])
            ?? fields["swift-task.fmt"]
    }

    private static func actorValue(_ fields: [String: String]) -> String? {
        value(fields, keys: ["actor", "executor", "swift-actor-id", "swift-actor"])
            ?? fields["swift-actor.fmt"]
    }

    private static func continuationValue(_ fields: [String: String], task: String?) -> String? {
        if let value = value(fields, keys: ["continuation", "continuation-id", "swift-continuation-id", "swift-continuation"]) {
            return value
        }
        guard let task,
              let state = value(fields, keys: ["state", "swift-task-state"]),
              state.localizedCaseInsensitiveContains("continuation") else {
            return nil
        }
        return "\(task) continuation"
    }

    private static func value(_ fields: [String: String], keys: [String]) -> String? {
        for key in keys {
            if let value = fields[key], !value.isEmpty { return value }
            if let value = fields["\(key).fmt"], !value.isEmpty { return value }
        }
        return nil
    }

    private static func addEdge(from: String, to: String, kind: String, set: inout Set<String>, edges: inout [SwiftConcurrencyEdge]) {
        let key = "\(from)\u{0000}\(to)\u{0000}\(kind)"
        guard set.insert(key).inserted else { return }
        edges.append(SwiftConcurrencyEdge(from: from, to: to, kind: kind))
    }
}
