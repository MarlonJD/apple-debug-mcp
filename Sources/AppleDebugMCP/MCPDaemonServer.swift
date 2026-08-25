// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppleDebugCore
import Darwin
import Foundation
import MCP
@preconcurrency import NIOCore
@preconcurrency import NIOHTTP1
@preconcurrency import NIOPosix

enum AppleDebugMCPDaemon {
    static func run() async throws {
        let server = try AppleDebugMCPDaemonServer()
        let stdinTask = Task {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    _ = FileHandle.standardInput.readDataToEndOfFile()
                    continuation.resume()
                }
            }
            await server.stop()
        }
        let signalQueue = DispatchQueue.global(qos: .userInitiated)
        let terminationSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: signalQueue)
        let interruptSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: signalQueue)
        terminationSource.setEventHandler {
            Task { await server.stop() }
        }
        interruptSource.setEventHandler {
            Task { await server.stop() }
        }
        terminationSource.resume()
        interruptSource.resume()

        defer {
            stdinTask.cancel()
            terminationSource.cancel()
            interruptSource.cancel()
            signal(SIGTERM, SIG_DFL)
            signal(SIGINT, SIG_DFL)
        }

        let endpoint = try await server.start()
        let endpointLine = "Apple Debug MCP daemon listening at \(endpoint.url.absoluteString)\n"
        FileHandle.standardOutput.write(Data(endpointLine.utf8))

        do {
            try await server.waitUntilStopped()
        } catch {
            await server.stop()
            await ToolCatalog.shutdown()
            throw error
        }

        await server.stop()
        await ToolCatalog.shutdown()
    }
}

actor AppleDebugMCPDaemonServer {
    private static let defaultPort = 49321

    private struct FixedSessionIDGenerator: SessionIDGenerator {
        let sessionID: String

        func generateSessionID() -> String {
            sessionID
        }
    }

    private struct SessionContext {
        let server: Server
        let transport: StatefulHTTPServerTransport
        var lastAccessedAt: Date
    }

    private let host = "127.0.0.1"
    private let port: Int
    private let endpointPath = "/mcp"
    private let healthPath = "/healthz"
    private let token: String
    private let endpointFileURL: URL
    private let validationPipeline: any HTTPRequestValidationPipeline
    private let eventLoopGroup: MultiThreadedEventLoopGroup

    private var channel: Channel?
    private var publishedEndpoint: AppleDebugDaemonEndpoint?
    private var sessions: [String: SessionContext] = [:]
    private var cleanupTask: Task<Void, Never>?
    private var stopped = false

    init() throws {
        self.token = Self.makeToken()
        self.endpointFileURL = AppleDebugDaemonEndpoint.defaultFileURL
        if let configuredPort = ProcessInfo.processInfo.environment["APPLE_DEBUG_MCP_PORT"],
            let parsedPort = Int(configuredPort),
            (0...65535).contains(parsedPort)
        {
            self.port = parsedPort
        } else {
            self.port = Self.defaultPort
        }
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        let resourceURL = URL(string: "http://127.0.0.1/mcp")!
        let bearerValidator = BearerTokenValidator(
            resourceMetadataURL: resourceURL,
            resourceIdentifier: resourceURL,
            tokenValidator: { [token] providedToken, _, _ in
                if Self.constantTimeEqual(providedToken, token) {
                    return .valid(BearerTokenInfo())
                }
                return .invalidToken(errorDescription: "Invalid local daemon token")
            }
        )

        self.validationPipeline = StandardValidationPipeline(validators: [
            OriginValidator.localhost(),
            bearerValidator,
            AcceptHeaderValidator(mode: .sseRequired),
            ContentTypeValidator(),
            ProtocolVersionValidator(),
            SessionValidator(),
        ])
    }

    func start() async throws -> AppleDebugDaemonEndpoint {
        guard channel == nil else {
            throw MCPError.internalError("MCP daemon is already running")
        }

        try prepareEndpointFile()
        stopped = false

        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 64)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { [self] channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(MCPDaemonHTTPHandler(app: self))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)

        do {
            let channel = try await bootstrap.bind(host: host, port: port).get()
            guard let boundPort = channel.localAddress?.port else {
                try? await channel.close()
                throw MCPError.internalError("MCP daemon did not expose a bound port")
            }

            let url = URL(string: "http://127.0.0.1:\(boundPort)\(endpointPath)")!
            let endpoint = AppleDebugDaemonEndpoint(
                url: url,
                token: token,
                pid: Int32(getpid())
            )
            try endpoint.write(to: endpointFileURL)
            self.channel = channel
            self.publishedEndpoint = endpoint
            cleanupTask = Task { [weak self] in
                await self?.sessionCleanupLoop()
            }
            return endpoint
        } catch {
            try? await eventLoopGroup.shutdownGracefully()
            throw error
        }
    }

    func waitUntilStopped() async throws {
        guard let channel else {
            throw MCPError.internalError("MCP daemon has not started")
        }
        try await channel.closeFuture.get()
    }

    func stop() async {
        guard !stopped else { return }
        stopped = true
        cleanupTask?.cancel()
        cleanupTask = nil

        for sessionID in Array(sessions.keys) {
            await closeSession(sessionID)
        }
        sessions.removeAll()

        if publishedEndpoint != nil {
            AppleDebugDaemonEndpoint.remove(from: endpointFileURL)
        }
        publishedEndpoint = nil

        try? await channel?.close()
        channel = nil
        try? await eventLoopGroup.shutdownGracefully()
    }

    var endpointPathForHTTP: String {
        endpointPath
    }

    func handleHTTPRequest(_ request: HTTPRequest) async -> HTTPResponse {
        let path = request.path ?? "/"
        if path == healthPath {
            guard request.method.uppercased() == "GET" else {
                return .error(statusCode: 405, .invalidRequest("Method Not Allowed"))
            }
            return healthResponse(for: request)
        }
        if path == "/shutdown" {
            guard request.method.uppercased() == "POST" else {
                return .error(statusCode: 405, .invalidRequest("Method Not Allowed"))
            }
            guard isAuthorized(request) else {
                return unauthorizedResponse()
            }
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(10))
                await self?.stop()
            }
            return .ok(headers: ["Cache-Control": "no-store"])
        }
        guard path == endpointPath else {
            return .error(statusCode: 404, .invalidRequest("Not Found"))
        }
        guard isAuthorized(request) else {
            return unauthorizedResponse()
        }

        let sessionID = request.header(HTTPHeaderName.sessionID)
        if let sessionID, var session = sessions[sessionID] {
            session.lastAccessedAt = Date()
            sessions[sessionID] = session
            let response = await session.transport.handleRequest(request)
            if request.method.uppercased() == "DELETE", response.statusCode == 200 {
                await closeSession(sessionID)
            }
            return response
        }

        if isInitializeRequest(request.body) {
            return await createSessionAndHandle(request)
        }

        if sessionID != nil {
            return .error(statusCode: 404, .invalidRequest("Not Found: Session not found or expired"))
        }
        return .error(
            statusCode: 400,
            .invalidRequest("Bad Request: Missing \(HTTPHeaderName.sessionID) header")
        )
    }

    private func createSessionAndHandle(_ request: HTTPRequest) async -> HTTPResponse {
        let sessionID = UUID().uuidString
        let transport = StatefulHTTPServerTransport(
            sessionIDGenerator: FixedSessionIDGenerator(sessionID: sessionID),
            validationPipeline: validationPipeline
        )
        let server = await AppleDebugMCPServerFactory.makeServer()

        do {
            try await server.start(transport: transport)
            sessions[sessionID] = SessionContext(
                server: server,
                transport: transport,
                lastAccessedAt: Date()
            )
            let response = await transport.handleRequest(request)
            if case .error = response {
                await closeSession(sessionID)
            }
            return response
        } catch {
            await server.stop()
            return .error(
                statusCode: 500,
                .internalError("Failed to create MCP session: \(error.localizedDescription)")
            )
        }
    }

    private func closeSession(_ sessionID: String) async {
        guard let session = sessions.removeValue(forKey: sessionID) else { return }
        await session.server.stop()
    }

    private func sessionCleanupLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(300))
            guard !Task.isCancelled else { return }
            let expiry = Date().addingTimeInterval(-3600)
            let expired = sessions.compactMap { sessionID, session in
                session.lastAccessedAt < expiry ? sessionID : nil
            }
            for sessionID in expired {
                await closeSession(sessionID)
            }
        }
    }

    private func prepareEndpointFile() throws {
        if let existing = try? AppleDebugDaemonEndpoint.load(from: endpointFileURL),
            existing.pid != Int32(getpid()),
            kill(existing.pid, 0) == 0
        {
            throw MCPError.internalError(
                "Another Apple Debug MCP daemon is already running (pid \(existing.pid))"
            )
        }
        AppleDebugDaemonEndpoint.remove(from: endpointFileURL)
    }

    private func healthResponse(for request: HTTPRequest) -> HTTPResponse {
        guard isAuthorized(request) else {
            return unauthorizedResponse()
        }
        let body = Data(
            "{\"status\":\"ok\",\"service\":\"apple-debug-mcp\",\"pid\":\(getpid())}".utf8
        )
        return .data(
            body,
            headers: [
                HTTPHeaderName.contentType: "application/json",
                "Cache-Control": "no-store",
            ]
        )
    }

    private func unauthorizedResponse() -> HTTPResponse {
        .error(
            statusCode: 401,
            .invalidRequest("Unauthorized"),
            extraHeaders: [HTTPHeaderName.wwwAuthenticate: "Bearer"]
        )
    }

    private func isAuthorized(_ request: HTTPRequest) -> Bool {
        guard let authorization = request.header(HTTPHeaderName.authorization) else {
            return false
        }
        let parts = authorization.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
        guard parts.count == 2,
            String(parts[0]).caseInsensitiveCompare("Bearer") == .orderedSame
        else {
            return false
        }
        return Self.constantTimeEqual(String(parts[1]), token)
    }

    private func isInitializeRequest(_ body: Data?) -> Bool {
        guard let body,
            let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
            object["id"] != nil,
            object["method"] as? String == "initialize"
        else {
            return false
        }
        return true
    }

    private static func makeToken() -> String {
        let first = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let second = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return first + second
    }

    private static func constantTimeEqual(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs.utf8)
        let right = Array(rhs.utf8)
        var difference = left.count ^ right.count
        for index in 0..<max(left.count, right.count) {
            let leftByte = index < left.count ? left[index] : 0
            let rightByte = index < right.count ? right[index] : 0
            difference |= Int(leftByte ^ rightByte)
        }
        return difference == 0
    }

}

private final class MCPDaemonHTTPHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private struct RequestState {
        var head: HTTPRequestHead
        var bodyBuffer: ByteBuffer
        var bodyTooLarge = false
    }

    private let app: AppleDebugMCPDaemonServer
    private var requestState: RequestState?
    private let maximumBodyBytes = 2 * 1024 * 1024

    init(app: AppleDebugMCPDaemonServer) {
        self.app = app
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head):
            requestState = RequestState(
                head: head,
                bodyBuffer: context.channel.allocator.buffer(capacity: 0)
            )
        case .body(var buffer):
            guard var state = requestState else { return }
            if state.bodyBuffer.readableBytes + buffer.readableBytes > maximumBodyBytes {
                state.bodyTooLarge = true
            } else if !state.bodyTooLarge {
                state.bodyBuffer.writeBuffer(&buffer)
            }
            requestState = state
        case .end:
            guard let state = requestState else { return }
            requestState = nil
            nonisolated(unsafe) let context = context
            Task {
                await self.handle(state: state, context: context)
            }
        }
    }

    private func handle(state: RequestState, context: ChannelHandlerContext) async {
        if state.bodyTooLarge {
            await write(
                .error(statusCode: 413, .invalidRequest("Request body exceeds 2 MiB")),
                version: state.head.version,
                context: context
            )
            return
        }

        let path = state.head.uri.split(separator: "?").first.map(String.init) ?? state.head.uri
        let request = makeHTTPRequest(from: state, path: path)
        let response = await app.handleHTTPRequest(request)
        await write(response, version: state.head.version, context: context)
    }

    private func makeHTTPRequest(from state: RequestState, path: String) -> HTTPRequest {
        var headers: [String: String] = [:]
        for (name, value) in state.head.headers {
            if let existing = headers[name] {
                headers[name] = existing + ", " + value
            } else {
                headers[name] = value
            }
        }

        let body: Data?
        if state.bodyBuffer.readableBytes > 0,
            let bytes = state.bodyBuffer.getBytes(
                at: state.bodyBuffer.readerIndex,
                length: state.bodyBuffer.readableBytes
            )
        {
            body = Data(bytes)
        } else {
            body = nil
        }

        return HTTPRequest(
            method: state.head.method.rawValue,
            headers: headers,
            body: body,
            path: path
        )
    }

    private func write(
        _ response: HTTPResponse,
        version: HTTPVersion,
        context: ChannelHandlerContext
    ) async {
        nonisolated(unsafe) let contextReference = context
        let eventLoop = contextReference.eventLoop
        let headers = response.headers

        switch response {
        case .stream(let stream, _):
            eventLoop.execute {
                var head = HTTPResponseHead(
                    version: version,
                    status: HTTPResponseStatus(statusCode: response.statusCode)
                )
                for (name, value) in headers {
                    head.headers.add(name: name, value: value)
                }
                if !head.headers.contains(name: "Transfer-Encoding") {
                    head.headers.add(name: "Transfer-Encoding", value: "chunked")
                }
                contextReference.write(self.wrapOutboundOut(.head(head)), promise: nil)
                contextReference.flush()
            }

            do {
                for try await chunk in stream {
                    eventLoop.execute {
                        var buffer = contextReference.channel.allocator.buffer(capacity: chunk.count)
                        buffer.writeBytes(chunk)
                        contextReference.writeAndFlush(
                            self.wrapOutboundOut(.body(.byteBuffer(buffer))),
                            promise: nil
                        )
                    }
                }
            } catch {
                // The client may close an SSE stream while the server keeps its session.
            }

            eventLoop.execute {
                contextReference.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
            }

        default:
            let body = response.bodyData
            eventLoop.execute {
                var head = HTTPResponseHead(
                    version: version,
                    status: HTTPResponseStatus(statusCode: response.statusCode)
                )
                for (name, value) in headers {
                    head.headers.add(name: name, value: value)
                }
                if !head.headers.contains(name: "Content-Length") {
                    head.headers.add(name: "Content-Length", value: "\(body?.count ?? 0)")
                }
                contextReference.write(self.wrapOutboundOut(.head(head)), promise: nil)
                if let body {
                    var buffer = contextReference.channel.allocator.buffer(capacity: body.count)
                    buffer.writeBytes(body)
                    contextReference.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
                }
                contextReference.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
            }
        }
    }
}
