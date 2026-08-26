// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import MCP
import AppleDebugCore

extension ToolCatalog {
    struct DAPProbeResult: Encodable {
        let response: DAPMessage
        let events: [DAPMessage]
    }

    struct DebugLaunchResult: Encodable {
        let sessionID: String
        let response: DAPMessage
    }

    struct SessionCloseResult: Encodable {
        let sessionID: String
        let closed: Bool
    }


    static func errorResult(_ error: Error) -> CallTool.Result {
        errorResult(error.localizedDescription)
    }

    static func errorResult(_ message: String) -> CallTool.Result {
        .init(
            content: [.text(text: message, annotations: nil, _meta: nil)],
            isError: true
        )
    }

    static func stringArray(from value: Value?) -> [String] {
        value?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    static func stringDictionary(from value: Value?) -> [String: String] {
        guard let object = value?.objectValue else { return [:] }
        return object.compactMapValues(\.stringValue)
    }

    static func crashArtifacts(from value: Value?) -> [CrashSymbolicationArtifact]? {
        guard let values = value?.arrayValue, !values.isEmpty, values.count <= 32 else {
            return nil
        }
        var artifacts: [CrashSymbolicationArtifact] = []
        for value in values {
            guard let object = value.objectValue,
                  let binaryPath = object["binaryPath"]?.stringValue,
                  let architecture = object["architecture"]?.stringValue,
                  !binaryPath.isEmpty,
                  !architecture.isEmpty else {
                return nil
            }
            artifacts.append(
                CrashSymbolicationArtifact(
                    imageName: object["imageName"]?.stringValue,
                    binaryPath: binaryPath,
                    architecture: architecture,
                    loadAddress: object["loadAddress"]?.stringValue
                )
            )
        }
        return artifacts
    }

    static func dapValueArray(from value: Value) -> [DAPValue]? {
        guard let values = value.arrayValue else { return nil }
        let converted = values.compactMap(dapValue(from:))
        return converted.count == values.count ? converted : nil
    }

    static func replayMemoryCaptureRequests(from value: Value?) -> [ReplayMemoryCaptureRequest]? {
        guard let value else { return [] }
        guard let values = value.arrayValue else { return nil }
        var requests: [ReplayMemoryCaptureRequest] = []
        requests.reserveCapacity(values.count)
        for value in values {
            guard let object = value.objectValue,
                  let memoryReference = object["memoryReference"]?.stringValue,
                  let count = object["count"]?.intValue else {
                return nil
            }
            requests.append(
                ReplayMemoryCaptureRequest(
                    memoryReference: memoryReference,
                    offset: object["offset"]?.intValue ?? 0,
                    count: count
                )
            )
        }
        return requests
    }

    static func replayStringMap(from value: Value?) -> [String: String]? {
        guard let value else { return [:] }
        guard let object = value.objectValue else { return nil }
        var result: [String: String] = [:]
        for (key, value) in object {
            guard let string = value.stringValue else { return nil }
            result[key] = string
        }
        return result
    }

    static func dapValue(from value: Value) -> DAPValue? {
        switch value {
        case .null:
            return .null
        case .bool(let value):
            return .boolean(value)
        case .int(let value):
            return .integer(value)
        case .double(let value):
            return .double(value)
        case .string(let value):
            return .string(value)
        case .data(_, let data):
            return .string(data.base64EncodedString())
        case .array(let values):
            return .array(values.compactMap(dapValue(from:)))
        case .object(let object):
            return .object(object.compactMapValues(dapValue(from:)))
        }
    }

    static func boolValue(from value: Value?, default defaultValue: Bool) -> Bool {
        value?.boolValue ?? defaultValue
    }

    static func intValue(from value: Value?) -> Int? {
        value?.intValue
    }

    static func doubleValue(from value: Value?) -> Double? {
        value?.doubleValue ?? value?.intValue.map(Double.init)
    }

    static func result<T: Encodable>(for value: T) -> CallTool.Result {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        do {
            let data = try encoder.encode(value)
            let text = String(decoding: data, as: UTF8.self)
            return .init(content: [.text(text: text, annotations: nil, _meta: nil)], isError: false)
        } catch {
            return .init(
                content: [.text(text: "Failed to encode result: \(error.localizedDescription)", annotations: nil, _meta: nil)],
                isError: true
            )
        }
    }
}
