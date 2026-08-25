// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// The discoverable address and bearer credential for the local MCP daemon.
///
/// The file containing this value is user-private and is intended for an MCP client
/// configuration helper. The token is never included in the menu-bar status text.
public struct AppleDebugDaemonEndpoint: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let url: URL
    public let token: String
    public let pid: Int32
    public let startedAt: Date

    public init(
        url: URL,
        token: String,
        pid: Int32,
        startedAt: Date = Date()
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.url = url
        self.token = token
        self.pid = pid
        self.startedAt = startedAt
    }

    public var healthURL: URL {
        urlForPath("/healthz")
    }

    public var shutdownURL: URL {
        urlForPath("/shutdown")
    }

    private func urlForPath(_ path: String) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.path = path
        components.query = nil
        components.fragment = nil
        return components.url!
    }

    public var authorizationHeader: String {
        "Bearer \(token)"
    }

    public static var defaultFileURL: URL {
        if let configured = ProcessInfo.processInfo.environment["APPLE_DEBUG_MCP_ENDPOINT_FILE"],
            !configured.isEmpty
        {
            return URL(fileURLWithPath: configured)
        }

        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return applicationSupport
            .appendingPathComponent("AppleDebugMCP", isDirectory: true)
            .appendingPathComponent("endpoint.json")
    }

    public func write(to fileURL: URL = Self.defaultFileURL) throws {
        try validate()

        let fileManager = FileManager.default
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directoryURL.path
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: fileURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    public static func load(from fileURL: URL = Self.defaultFileURL) throws -> Self {
        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw EndpointError.invalidFile("endpoint path is not a regular file")
        }

        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0o777
        guard permissions & 0o077 == 0 else {
            throw EndpointError.invalidFile("endpoint file must not be group/world accessible")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let endpoint = try decoder.decode(Self.self, from: Data(contentsOf: fileURL))
        try endpoint.validate()
        return endpoint
    }

    public static func remove(from fileURL: URL = Self.defaultFileURL) {
        try? FileManager.default.removeItem(at: fileURL)
    }

    public static func removeIfOwned(
        pid: Int32,
        token: String,
        from fileURL: URL = Self.defaultFileURL
    ) {
        guard let endpoint = try? load(from: fileURL),
            endpoint.pid == pid,
            endpoint.token == token
        else {
            return
        }
        remove(from: fileURL)
    }

    public func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw EndpointError.invalidValue("unsupported endpoint schema version")
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme == "http",
            components.host == "127.0.0.1",
            let port = components.port,
            (1...65535).contains(port),
            components.path == "/mcp",
            components.query == nil,
            components.fragment == nil
        else {
            throw EndpointError.invalidValue("endpoint must be http://127.0.0.1:<port>/mcp")
        }
        guard pid > 0 else {
            throw EndpointError.invalidValue("endpoint process ID must be positive")
        }
        guard token.count >= 32,
            token.allSatisfy({ character in
                character.isASCII && !character.isWhitespace && character != "\u{7f}"
            })
        else {
            throw EndpointError.invalidValue("endpoint token is missing or malformed")
        }
    }
}

public enum EndpointError: Error, LocalizedError, Equatable {
    case invalidFile(String)
    case invalidValue(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFile(let message), .invalidValue(let message):
            return message
        }
    }
}
