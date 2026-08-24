// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum CrashReportError: Error, Equatable, LocalizedError, Sendable {
    case fileNotFound
    case notRegularFile
    case fileTooLarge
    case invalidJSON
    case unsupportedFormat

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Crash report was not found."
        case .notRegularFile:
            return "Crash report path is not a regular file."
        case .fileTooLarge:
            return "Crash report exceeds the 32 MB analysis limit."
        case .invalidJSON:
            return "The .ips crash report does not contain a valid JSON object."
        case .unsupportedFormat:
            return "Only Apple .crash text reports and .ips JSON reports are supported."
        }
    }
}

public struct CrashFrame: Codable, Equatable, Sendable {
    public let index: Int
    public let image: String?
    public let address: String?
    public let symbol: String?

    public init(index: Int, image: String?, address: String?, symbol: String?) {
        self.index = index
        self.image = image
        self.address = address
        self.symbol = symbol
    }
}

public struct CrashThread: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String?
    public let crashed: Bool
    public let frames: [CrashFrame]

    public init(id: Int, name: String?, crashed: Bool, frames: [CrashFrame]) {
        self.id = id
        self.name = name
        self.crashed = crashed
        self.frames = frames
    }
}

public struct CrashImage: Codable, Equatable, Sendable {
    public let name: String?
    public let uuid: String?
    public let path: String?
    public let baseAddress: String?

    public init(name: String?, uuid: String?, path: String?, baseAddress: String?) {
        self.name = name
        self.uuid = uuid
        self.path = path
        self.baseAddress = baseAddress
    }
}

public struct CrashReport: Codable, Equatable, Sendable {
    public let path: String
    public let format: String
    public let processName: String?
    public let processID: Int?
    public let bundleIdentifier: String?
    public let exceptionType: String?
    public let exceptionCodes: String?
    public let signal: String?
    public let terminationReason: String?
    public let crashedThread: Int?
    public let threads: [CrashThread]
    public let images: [CrashImage]
    public let fields: [String: String]

    public init(
        path: String,
        format: String,
        processName: String?,
        processID: Int?,
        bundleIdentifier: String?,
        exceptionType: String?,
        exceptionCodes: String?,
        signal: String?,
        terminationReason: String?,
        crashedThread: Int?,
        threads: [CrashThread],
        images: [CrashImage],
        fields: [String: String]
    ) {
        self.path = path
        self.format = format
        self.processName = processName
        self.processID = processID
        self.bundleIdentifier = bundleIdentifier
        self.exceptionType = exceptionType
        self.exceptionCodes = exceptionCodes
        self.signal = signal
        self.terminationReason = terminationReason
        self.crashedThread = crashedThread
        self.threads = threads
        self.images = images
        self.fields = fields
    }
}

public enum CrashReportAnalyzer {
    private static let maximumFileSize = 32 * 1024 * 1024

    public static func inspect(path: String) throws -> CrashReport {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CrashReportError.fileNotFound
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let type = attributes[.type] as? FileAttributeType, type == .typeRegular else {
            throw CrashReportError.notRegularFile
        }
        if let size = attributes[.size] as? NSNumber, size.intValue > maximumFileSize {
            throw CrashReportError.fileTooLarge
        }

        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let leading = String(decoding: data.prefix(64), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if leading.hasPrefix("{") {
            return try inspectIPS(path: url.path, data: data)
        }
        if url.pathExtension.lowercased() == "crash" || leading.contains("Process:") {
            return inspectText(path: url.path, text: String(decoding: data, as: UTF8.self))
        }
        throw CrashReportError.unsupportedFormat
    }

    private static func inspectIPS(path: String, data: Data) throws -> CrashReport {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CrashReportError.invalidJSON
        }
        let payload = root["payload"] as? [String: Any] ?? root
        let exception = payload["exception"] as? [String: Any] ?? [:]
        let termination = payload["termination"] as? [String: Any] ?? [:]
        let processName = firstString(payload, keys: ["name", "processName", "procName"])
        let processID = firstInt(payload, keys: ["pid", "processID", "processId"])
        let bundleIdentifier = firstString(payload, keys: ["bundleID", "bundleIdentifier"])
        let exceptionType = firstString(exception, keys: ["type", "exceptionType"])
            ?? firstString(payload, keys: ["exceptionType"])
        let exceptionCodes = firstString(exception, keys: ["codes", "exceptionCodes"])
            ?? firstString(payload, keys: ["exceptionCodes"])
        let signal = firstString(exception, keys: ["signal", "signalName"])
        let terminationReason = firstString(termination, keys: ["reason", "namespace"])
            ?? firstString(payload, keys: ["terminationReason"])
        let crashedThread = firstInt(payload, keys: ["faultingThread", "crashedThread"])
        let threads = parseIPSthreads(payload["threads"] as? [[String: Any]])
        let images = parseIPSImages(payload["usedImages"] as? [[String: Any]])

        return CrashReport(
            path: path,
            format: "ips",
            processName: processName,
            processID: processID,
            bundleIdentifier: bundleIdentifier,
            exceptionType: exceptionType,
            exceptionCodes: exceptionCodes,
            signal: signal,
            terminationReason: terminationReason,
            crashedThread: crashedThread,
            threads: threads,
            images: images,
            fields: scalarFields(payload)
        )
    }

    private static func inspectText(path: String, text: String) -> CrashReport {
        let lines = text.components(separatedBy: .newlines)
        var fields: [String: String] = [:]
        for line in lines {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: separator)...])
                .trimmingCharacters(in: .whitespaces)
            if !key.isEmpty, !value.isEmpty {
                fields[key] = value
            }
        }

        let process = fields["Process"].map(parseProcess)
        let crashedThread = fields["Triggered by Thread"].flatMap(Int.init)
        let threads = parseTextThreads(lines: lines)
        return CrashReport(
            path: path,
            format: "crash",
            processName: process?.name,
            processID: process?.id,
            bundleIdentifier: fields["Identifier"],
            exceptionType: fields["Exception Type"],
            exceptionCodes: fields["Exception Codes"],
            signal: fields["Signal"],
            terminationReason: fields["Termination Reason"],
            crashedThread: crashedThread,
            threads: threads,
            images: [],
            fields: fields
        )
    }

    private static func parseIPSthreads(_ values: [[String: Any]]?) -> [CrashThread] {
        (values ?? []).compactMap { value in
            guard let id = firstInt(value, keys: ["id", "threadID", "threadId"]) else { return nil }
            let frames = (value["frames"] as? [[String: Any]] ?? []).enumerated().map { index, frame in
                CrashFrame(
                    index: index,
                    image: firstString(frame, keys: ["image", "imageName"]),
                    address: firstString(frame, keys: ["address", "imageOffset", "symbolLocation"]),
                    symbol: firstString(frame, keys: ["symbol", "function"])
                )
            }
            return CrashThread(
                id: id,
                name: firstString(value, keys: ["name", "threadName"]),
                crashed: firstBool(value, keys: ["triggered", "crashed", "faulting"]) ?? false,
                frames: frames
            )
        }
    }

    private static func parseIPSImages(_ values: [[String: Any]]?) -> [CrashImage] {
        (values ?? []).map { value in
            CrashImage(
                name: firstString(value, keys: ["name", "imageName"]),
                uuid: firstString(value, keys: ["uuid", "imageUUID"]),
                path: firstString(value, keys: ["path"]),
                baseAddress: firstString(value, keys: ["base", "baseAddress"])
            )
        }
    }

    private static func parseTextThreads(lines: [String]) -> [CrashThread] {
        var threads: [CrashThread] = []
        var currentID: Int?
        var currentName: String?
        var currentCrashed = false
        var currentFrames: [CrashFrame] = []

        func flush() {
            guard let currentID else { return }
            threads.append(
                CrashThread(
                    id: currentID,
                    name: currentName,
                    crashed: currentCrashed,
                    frames: currentFrames
                )
            )
        }

        for line in lines {
            if line.hasPrefix("Thread ") {
                flush()
                let rest = line.dropFirst("Thread ".count)
                let idString = rest.prefix { $0.isNumber }
                currentID = Int(idString)
                currentCrashed = line.contains("Crashed")
                currentName = nil
                currentFrames = []
                continue
            }
            guard currentID != nil else { continue }
            let parts = line.split(maxSplits: 3, whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 3, let index = Int(parts[0]) else { continue }
            currentFrames.append(
                CrashFrame(
                    index: index,
                    image: String(parts[1]),
                    address: String(parts[2]),
                    symbol: parts.count == 4 ? String(parts[3]) : nil
                )
            )
        }
        flush()
        return threads
    }

    private static func parseProcess(_ value: String) -> (name: String?, id: Int?) {
        guard let open = value.lastIndex(of: "["), value.last == "]" else {
            return (value, nil)
        }
        let name = value[..<open].trimmingCharacters(in: .whitespaces)
        let id = Int(value[value.index(after: open)..<value.index(before: value.endIndex)])
        return (name.isEmpty ? nil : name, id)
    }

    private static func scalarFields(_ dictionary: [String: Any]) -> [String: String] {
        dictionary.compactMapValues { value in
            if let value = value as? String { return value }
            if let value = value as? NSNumber { return value.stringValue }
            return nil
        }
    }

    private static func firstString(_ dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String { return value }
            if let value = dictionary[key] as? NSNumber { return value.stringValue }
        }
        return nil
    }

    private static func firstInt(_ dictionary: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = dictionary[key] as? NSNumber { return value.intValue }
            if let value = dictionary[key] as? String, let parsed = Int(value) { return parsed }
        }
        return nil
    }

    private static func firstBool(_ dictionary: [String: Any], keys: [String]) -> Bool? {
        for key in keys {
            if let value = dictionary[key] as? Bool { return value }
            if let value = dictionary[key] as? NSNumber { return value.boolValue }
        }
        return nil
    }
}
