// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct AppleDebugPluginManifest: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let version: String
    public let capabilities: [String]
    public let entrypoint: String?

    public init(id: String, name: String, version: String, capabilities: [String], entrypoint: String? = nil) {
        self.id = id
        self.name = name
        self.version = version
        self.capabilities = capabilities
        self.entrypoint = entrypoint
    }
}

public enum AppleDebugPluginError: Error, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case directoryNotFound
    case manifestTooLarge
    case invalidManifest(String)
    case duplicateIdentifier

    public var errorDescription: String? {
        switch self {
        case .invalidRequest: return "Plugin manifest request is invalid or exceeds its bounded limits."
        case .directoryNotFound: return "The plugin manifest directory was not found."
        case .manifestTooLarge: return "A plugin manifest exceeds the configured size limit."
        case .invalidManifest(let message): return "Plugin manifest is invalid: \(message)"
        case .duplicateIdentifier: return "Plugin manifest identifiers must be unique."
        }
    }
}

public protocol AppleDebugPlugin: Sendable {
    var manifest: AppleDebugPluginManifest { get }
    func analyze(input: DAPValue) async throws -> DAPValue
}

public actor AppleDebugPluginRegistry {
    public static let shared = AppleDebugPluginRegistry()
    private var plugins: [String: any AppleDebugPlugin] = [:]

    public init() {}

    public func register(_ plugin: any AppleDebugPlugin) throws {
        try Self.validate(plugin.manifest)
        guard plugins[plugin.manifest.id] == nil else { throw AppleDebugPluginError.duplicateIdentifier }
        plugins[plugin.manifest.id] = plugin
    }

    public func manifests() -> [AppleDebugPluginManifest] {
        plugins.values.map(\.manifest).sorted { $0.id < $1.id }
    }

    public func invoke(id: String, input: DAPValue) async throws -> DAPValue {
        guard let plugin = plugins[id] else { throw AppleDebugPluginError.invalidManifest("Unknown plugin: \(id)") }
        return try await plugin.analyze(input: input)
    }

    private static func validate(_ manifest: AppleDebugPluginManifest) throws {
        guard !manifest.id.isEmpty, manifest.id.utf8.count <= 128, !manifest.id.contains("\0"),
              !manifest.name.isEmpty, manifest.name.utf8.count <= 256,
              !manifest.version.isEmpty, manifest.version.utf8.count <= 64,
              manifest.capabilities.count <= 128,
              manifest.capabilities.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 128 && !$0.contains("\0") }) else {
            throw AppleDebugPluginError.invalidManifest("identifier, name, version, or capability bounds are invalid")
        }
    }
}

public enum AppleDebugPluginManifestService {
    private static let maximumManifests = 128
    private static let maximumManifestSize = 64 * 1024

    public static func discover(directory: String) throws -> [AppleDebugPluginManifest] {
        guard !directory.isEmpty, directory.utf8.count <= 4_096, !directory.contains("\0"), URL(fileURLWithPath: directory).path.hasPrefix("/") else {
            throw AppleDebugPluginError.invalidRequest
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw AppleDebugPluginError.directoryNotFound
        }
        let entries = try FileManager.default.contentsOfDirectory(atPath: directory)
            .filter { $0.hasSuffix(".appledebugplugin.json") }
            .sorted()
        guard entries.count <= maximumManifests else { throw AppleDebugPluginError.invalidRequest }
        var manifests: [AppleDebugPluginManifest] = []
        for entry in entries {
            let url = URL(fileURLWithPath: directory).appendingPathComponent(entry)
            let data: Data
            do {
                data = try AppleBoundedFile.readData(
                    atPath: url.path,
                    maximumSize: maximumManifestSize
                )
            } catch AppleBoundedFileError.tooLarge {
                throw AppleDebugPluginError.manifestTooLarge
            } catch {
                throw AppleDebugPluginError.invalidManifest("manifest must be a regular readable file")
            }
            do {
                let manifest = try JSONDecoder().decode(AppleDebugPluginManifest.self, from: data)
                try validate(manifest)
                guard !manifests.contains(where: { $0.id == manifest.id }) else { throw AppleDebugPluginError.duplicateIdentifier }
                manifests.append(manifest)
            } catch let error as AppleDebugPluginError {
                throw error
            } catch {
                throw AppleDebugPluginError.invalidManifest(error.localizedDescription)
            }
        }
        return manifests
    }

    private static func validate(_ manifest: AppleDebugPluginManifest) throws {
        guard !manifest.id.isEmpty, manifest.id.utf8.count <= 128, !manifest.id.contains("\0"),
              !manifest.name.isEmpty, manifest.name.utf8.count <= 256,
              !manifest.version.isEmpty, manifest.version.utf8.count <= 64,
              manifest.capabilities.count <= 128,
              manifest.capabilities.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 128 && !$0.contains("\0") }) else {
            throw AppleDebugPluginError.invalidManifest("identifier, name, version, or capability bounds are invalid")
        }
    }
}
