// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct AppleReproBundleManifest: Codable, Equatable, Sendable {
    public let udid: String
    public let bundleID: String
    public let createdAt: String
    public let files: [String]
    public let appInfoIncluded: Bool
    public let logsIncluded: Bool

    public init(udid: String, bundleID: String, createdAt: String, files: [String], appInfoIncluded: Bool, logsIncluded: Bool) {
        self.udid = udid
        self.bundleID = bundleID
        self.createdAt = createdAt
        self.files = files
        self.appInfoIncluded = appInfoIncluded
        self.logsIncluded = logsIncluded
    }
}

public struct AppleReproBundleResult: Codable, Equatable, Sendable {
    public let outputDirectory: String
    public let manifest: AppleReproBundleManifest

    public init(outputDirectory: String, manifest: AppleReproBundleManifest) {
        self.outputDirectory = outputDirectory
        self.manifest = manifest
    }
}

public enum AppleReproBundleError: Error, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case mutationDisabled
    case unknownSimulator
    case commandFailed(String)
    case outputTooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidRequest: return "Repro bundle request is invalid or exceeds its bounded limits."
        case .mutationDisabled: return "Repro bundle capture requires APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1."
        case .unknownSimulator: return "The selected Simulator is not available."
        case .commandFailed(let message): return "Repro bundle capture failed: \(message)"
        case .outputTooLarge: return "Repro bundle inputs exceed the configured size limit."
        }
    }
}

public enum AppleReproBundleService {
    private static let maximumPaths = 8
    private static let maximumCopiedBytes: UInt64 = 512 * 1024 * 1024

    public static func capture(
        udid: String,
        bundleID: String,
        outputDirectory: String,
        includeScreenshot: Bool = true,
        includeAppInfo: Bool = true,
        includeLogs: Bool = true,
        tracePaths: [String] = [],
        crashPath: String? = nil
    ) throws -> AppleReproBundleResult {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION"] == "1" else {
            throw AppleReproBundleError.mutationDisabled
        }
        guard !udid.isEmpty, !bundleID.isEmpty, udid.utf8.count <= 256, bundleID.utf8.count <= 256,
              !udid.contains("\0"), !bundleID.contains("\0"),
              validOutputDirectory(outputDirectory), tracePaths.count <= maximumPaths,
              tracePaths.allSatisfy(validTracePath), crashPath.map(validCrashPath) ?? true else {
            throw AppleReproBundleError.invalidRequest
        }
        guard try SimulatorService.list().contains(where: { $0.udid == udid }) else {
            throw AppleReproBundleError.unknownSimulator
        }
        try FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: false)
        var files: [String] = []
        var copiedBytes: UInt64 = 0
        do {
            if includeScreenshot {
                let path = URL(fileURLWithPath: outputDirectory).appendingPathComponent("screenshot.png").path
                _ = try SimulatorService.screenshot(udid: udid, path: path)
                files.append("screenshot.png")
            }
            if includeAppInfo {
                let info = try SimulatorService.appInfo(udid: udid, bundleID: bundleID)
                try info.output.write(toFile: URL(fileURLWithPath: outputDirectory).appendingPathComponent("appinfo.txt").path, atomically: true, encoding: .utf8)
                files.append("appinfo.txt")
            }
            if includeLogs {
                let logs = try AppleLogService.show(target: udid, last: "30s")
                try JSONEncoder().encode(logs).write(to: URL(fileURLWithPath: outputDirectory).appendingPathComponent("logs.json"), options: .atomic)
                files.append("logs.json")
            }
            for path in tracePaths {
                let name = URL(fileURLWithPath: path).lastPathComponent
                let destination = URL(fileURLWithPath: outputDirectory).appendingPathComponent(name)
                copiedBytes += try copyBounded(path: path, to: destination.path, remaining: maximumCopiedBytes - copiedBytes)
                files.append(name)
            }
            if let crashPath {
                let name = URL(fileURLWithPath: crashPath).lastPathComponent
                let destination = URL(fileURLWithPath: outputDirectory).appendingPathComponent(name)
                copiedBytes += try copyBounded(path: crashPath, to: destination.path, remaining: maximumCopiedBytes - copiedBytes)
                files.append(name)
            }
            files.append("manifest.json")
            let createdAt = ISO8601DateFormatter().string(from: Date())
            let manifest = AppleReproBundleManifest(udid: udid, bundleID: bundleID, createdAt: createdAt, files: files.sorted(), appInfoIncluded: includeAppInfo, logsIncluded: includeLogs)
            try JSONEncoder().encode(manifest).write(to: URL(fileURLWithPath: outputDirectory).appendingPathComponent("manifest.json"), options: .atomic)
            return AppleReproBundleResult(outputDirectory: outputDirectory, manifest: manifest)
        } catch let error as AppleReproBundleError {
            throw error
        } catch {
            throw AppleReproBundleError.commandFailed(error.localizedDescription)
        }
    }

    private static func validOutputDirectory(_ path: String) -> Bool {
        !path.isEmpty && path.utf8.count <= 4_096 && !path.contains("\0") && URL(fileURLWithPath: path).path.hasPrefix("/") && !FileManager.default.fileExists(atPath: path)
    }

    private static func validTracePath(_ path: String) -> Bool {
        !path.isEmpty && path.hasSuffix(".trace") && URL(fileURLWithPath: path).path.hasPrefix("/") && FileManager.default.fileExists(atPath: path)
    }

    private static func validCrashPath(_ path: String) -> Bool {
        (path.hasSuffix(".crash") || path.hasSuffix(".ips")) && URL(fileURLWithPath: path).path.hasPrefix("/") && FileManager.default.fileExists(atPath: path)
    }

    private static func copyBounded(path: String, to destination: String, remaining: UInt64) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard let size = attributes[.size] as? NSNumber, size.uint64Value <= remaining else { throw AppleReproBundleError.outputTooLarge }
        try FileManager.default.copyItem(atPath: path, toPath: destination)
        return size.uint64Value
    }
}
