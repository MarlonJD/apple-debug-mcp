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
    case invalidRequest(String)

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
        case .invalidRequest(let message):
            return message
        }
    }
}

public enum CrashFrameLocationKind: String, Codable, Equatable, Sendable {
    case absolute
    case imageRelative
    case unknown
}

public struct CrashFrame: Codable, Equatable, Sendable {
    public let index: Int
    public let image: String?
    public let address: String?
    public let symbol: String?
    public let imageIndex: Int?
    public let imageOffset: String?
    public let locationKind: CrashFrameLocationKind

    public init(
        index: Int,
        image: String?,
        address: String?,
        symbol: String?,
        imageIndex: Int? = nil,
        imageOffset: String? = nil,
        locationKind: CrashFrameLocationKind = .absolute
    ) {
        self.index = index
        self.image = image
        self.address = address
        self.symbol = symbol
        self.imageIndex = imageIndex
        self.imageOffset = imageOffset
        self.locationKind = imageOffset == nil ? locationKind : .imageRelative
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
    public let imageIndex: Int?
    public let name: String?
    public let uuid: String?
    public let architecture: String?
    public let path: String?
    public let baseAddress: String?
    public let size: String?
    public let endAddress: String?

    public init(
        name: String?,
        uuid: String?,
        path: String?,
        baseAddress: String?,
        imageIndex: Int? = nil,
        architecture: String? = nil,
        size: String? = nil,
        endAddress: String? = nil
    ) {
        self.imageIndex = imageIndex
        self.name = name
        self.uuid = uuid
        self.architecture = architecture
        self.path = path
        self.baseAddress = baseAddress
        self.size = size
        self.endAddress = endAddress
    }

    public var normalizedUUID: String? {
        uuid.flatMap(MachOUUID.normalize)
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
    public let observedImageCount: Int
    public let observedThreadCount: Int
    public let observedFrameCount: Int
    public let truncated: Bool

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
        fields: [String: String],
        observedImageCount: Int? = nil,
        observedThreadCount: Int? = nil,
        observedFrameCount: Int? = nil,
        truncated: Bool = false
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
        self.observedImageCount = observedImageCount ?? images.count
        self.observedThreadCount = observedThreadCount ?? threads.count
        self.observedFrameCount = observedFrameCount ?? threads.reduce(0) { $0 + $1.frames.count }
        self.truncated = truncated
    }
}

public struct CrashSymbolicationArtifact: Codable, Equatable, Sendable {
    public let imageName: String?
    public let binaryPath: String
    public let architecture: String
    public let dSYMPath: String?

    public init(
        imageName: String? = nil,
        binaryPath: String,
        architecture: String,
        dSYMPath: String? = nil
    ) {
        self.imageName = imageName
        self.binaryPath = binaryPath
        self.architecture = architecture
        self.dSYMPath = dSYMPath
    }
}

public enum CrashImageMatchStatus: String, Codable, Equatable, Sendable {
    case matched
    case missingCrashIdentity
    case wrongUUID
    case wrongArchitecture
    case noMatchingArtifact
    case ambiguousProvider
    case invalidArtifact
    case unsupportedArtifact
}

public enum CrashFrameSymbolicationStatus: String, Codable, Equatable, Sendable {
    case resolvedSourceLine
    case resolvedSymbolOnly
    case unresolved
    case missingImageIdentity
    case wrongUUID
    case wrongArchitecture
    case noMatchingArtifact
    case ambiguousProvider
    case invalidAddress
    case invalidLoadAddress
    case addressOutOfRange
    case artifactChanged
    case missingDebugProvider
    case toolFailure
    case budgetExceeded
}

public enum CrashSymbolicationOutcome: String, Codable, Equatable, Sendable {
    case complete
    case partial
    case failed
}

public struct CrashSymbolicatedImage: Codable, Equatable, Sendable {
    public let imageIndex: Int
    public let name: String?
    public let uuid: String?
    public let rawUUID: String?
    public let architecture: String?
    public let matchStatus: CrashImageMatchStatus
    public let artifactPath: String?
    public let debugArtifactPath: String?
    public let embeddedDebugProvider: Bool
    public let preferredTextAddress: String?
    public let runtimeBase: String?
    public let slide: String?
    public let diagnostic: String?

    public init(
        imageIndex: Int,
        name: String?,
        uuid: String?,
        rawUUID: String? = nil,
        architecture: String?,
        matchStatus: CrashImageMatchStatus,
        artifactPath: String? = nil,
        debugArtifactPath: String? = nil,
        embeddedDebugProvider: Bool = false,
        preferredTextAddress: String? = nil,
        runtimeBase: String? = nil,
        slide: String? = nil,
        diagnostic: String? = nil
    ) {
        self.imageIndex = imageIndex
        self.name = name
        self.uuid = uuid
        self.rawUUID = rawUUID
        self.architecture = architecture
        self.matchStatus = matchStatus
        self.artifactPath = artifactPath
        self.debugArtifactPath = debugArtifactPath
        self.embeddedDebugProvider = embeddedDebugProvider
        self.preferredTextAddress = preferredTextAddress
        self.runtimeBase = runtimeBase
        self.slide = slide
        self.diagnostic = diagnostic
    }
}

public struct CrashSymbolicatedFrame: Codable, Equatable, Sendable {
    public let threadID: Int
    public let frameIndex: Int
    public let image: String?
    public let address: String?
    public let originalSymbol: String?
    public let artifactPath: String?
    public let symbol: String?
    public let error: String?
    public let imageIndex: Int?
    public let locationKind: CrashFrameLocationKind
    public let resolvedAddress: String?
    public let matchStatus: CrashImageMatchStatus
    public let status: CrashFrameSymbolicationStatus
    public let quality: String?
    public let sourceFile: String?
    public let sourceLine: Int?
    public let diagnostic: String?

    public init(
        threadID: Int,
        frameIndex: Int,
        image: String?,
        address: String?,
        originalSymbol: String?,
        artifactPath: String?,
        symbol: String?,
        error: String?,
        imageIndex: Int? = nil,
        locationKind: CrashFrameLocationKind = .absolute,
        resolvedAddress: String? = nil,
        matchStatus: CrashImageMatchStatus = .noMatchingArtifact,
        status: CrashFrameSymbolicationStatus = .unresolved,
        quality: String? = nil,
        sourceFile: String? = nil,
        sourceLine: Int? = nil,
        diagnostic: String? = nil
    ) {
        self.threadID = threadID
        self.frameIndex = frameIndex
        self.image = image
        self.address = address
        self.originalSymbol = originalSymbol
        self.artifactPath = artifactPath
        self.symbol = symbol
        self.error = error
        self.imageIndex = imageIndex
        self.locationKind = locationKind
        self.resolvedAddress = resolvedAddress
        self.matchStatus = matchStatus
        self.status = status
        self.quality = quality
        self.sourceFile = sourceFile
        self.sourceLine = sourceLine
        self.diagnostic = diagnostic
    }
}

public struct CrashSymbolicationReport: Codable, Equatable, Sendable {
    public let crash: CrashReport
    public let artifacts: [CrashSymbolicationArtifact]
    public let images: [CrashSymbolicatedImage]
    public let frames: [CrashSymbolicatedFrame]
    public let unmatchedFrameCount: Int
    public let outcome: CrashSymbolicationOutcome
    public let observedImageCount: Int
    public let returnedImageCount: Int
    public let observedThreadCount: Int
    public let returnedThreadCount: Int
    public let observedFrameCount: Int
    public let returnedFrameCount: Int
    public let atosInvocationCount: Int
    public let diagnostics: [String]
    public let diagnosticsTruncated: Bool
    public let truncated: Bool

    public init(
        crash: CrashReport,
        artifacts: [CrashSymbolicationArtifact],
        frames: [CrashSymbolicatedFrame],
        unmatchedFrameCount: Int,
        images: [CrashSymbolicatedImage] = [],
        outcome: CrashSymbolicationOutcome = .partial,
        observedImageCount: Int? = nil,
        returnedImageCount: Int? = nil,
        observedThreadCount: Int? = nil,
        returnedThreadCount: Int? = nil,
        observedFrameCount: Int? = nil,
        returnedFrameCount: Int? = nil,
        atosInvocationCount: Int = 0,
        diagnostics: [String] = [],
        diagnosticsTruncated: Bool = false,
        truncated: Bool = false
    ) {
        self.crash = crash
        self.artifacts = artifacts
        self.images = images
        self.frames = frames
        self.unmatchedFrameCount = unmatchedFrameCount
        self.outcome = outcome
        self.observedImageCount = observedImageCount ?? crash.observedImageCount
        self.returnedImageCount = returnedImageCount ?? crash.images.count
        self.observedThreadCount = observedThreadCount ?? crash.observedThreadCount
        self.returnedThreadCount = returnedThreadCount ?? crash.threads.count
        self.observedFrameCount = observedFrameCount ?? crash.observedFrameCount
        self.returnedFrameCount = returnedFrameCount ?? frames.count
        self.atosInvocationCount = atosInvocationCount
        self.diagnostics = diagnostics
        self.diagnosticsTruncated = diagnosticsTruncated
        self.truncated = truncated
    }
}

public enum CrashSymbolicationService {
    private static let maximumImages = 256
    private static let maximumThreads = 128
    private static let maximumFrames = 2_048
    private static let maximumArtifacts = 32
    private static let maximumAtosInvocations = 32
    private static let maximumDiagnosticBytes = 4 * 1024
    private static let maximumAggregateDiagnosticBytes = 256 * 1024
    private static let maximumBatchMilliseconds = 5_000
    private static let maximumCumulativeSeconds = 30.0

    private struct PreparedArtifact {
        let artifact: CrashSymbolicationArtifact
        let layout: AppleArtifactLayout
        let slice: MachOSliceReport?
        let role: AppleArtifactKind

        var key: String? {
            guard let slice, let uuid = slice.uuid else { return nil }
            return "\(uuid)|\(slice.architecture.name)"
        }
    }

    private struct ImageMatch {
        let status: CrashImageMatchStatus
        let image: CrashImage
        let imageArtifact: PreparedArtifact?
        let debugArtifact: PreparedArtifact?
        let diagnostic: String?
    }

    private struct PendingFrame {
        let resultIndex: Int
        let frame: CrashFrame
        let imageMatch: ImageMatch
        let resolvedAddress: UInt64
        let validation: SymbolicationAddressValidation
        let toolPath: String
        let debugAvailable: Bool
        let groupKey: BatchKey
    }

    private struct BatchKey: Hashable {
        let path: String
        let architecture: String
        let loadAddress: UInt64
    }

    private struct Diagnostics {
        var values: [String] = []
        var bytes = 0
        var truncated = false
        private var indexes: [String: Int] = [:]

        mutating func append(_ value: String?) -> String? {
            guard let value, !value.isEmpty else { return nil }
            let prefix = Array(value.utf8.prefix(maximumDiagnosticBytes + 1))
            let bounded: String
            if prefix.count > maximumDiagnosticBytes {
                bounded = String(decoding: prefix.prefix(maximumDiagnosticBytes - 3), as: UTF8.self) + "..."
                truncated = true
            } else {
                bounded = String(decoding: prefix, as: UTF8.self)
            }
            if let index = indexes[bounded] {
                return "[diagnostic repeated; see diagnostics[\(index)]]"
            }
            guard bytes < maximumAggregateDiagnosticBytes else {
                truncated = true
                return "[diagnostic omitted: aggregate diagnostic budget exhausted]"
            }
            let remaining = maximumAggregateDiagnosticBytes - bytes
            let accepted = String(decoding: Array(bounded.utf8.prefix(remaining)), as: UTF8.self)
            if accepted.utf8.count < bounded.utf8.count { truncated = true }
            indexes[bounded] = values.count
            values.append(accepted)
            bytes += accepted.utf8.count
            return accepted
        }
    }

    public static func symbolize(
        path: String,
        artifacts: [CrashSymbolicationArtifact],
        toolRunner: SymbolicationToolRunner? = nil,
        clock: SymbolicationClock = .systemUptime
    ) throws -> CrashSymbolicationReport {
        guard !artifacts.isEmpty, artifacts.count <= maximumArtifacts else {
            throw CrashReportError.invalidRequest("Crash symbolication requires between 1 and 32 artifacts.")
        }
        let started = clock.now()
        let crash = try CrashReportAnalyzer.inspect(path: path)
        var diagnostics = Diagnostics()
        let prepared = artifacts.flatMap { artifact in
            prepare(artifact: artifact, diagnostics: &diagnostics)
        }
        let imageProviders = prepared.filter { $0.role == .binary || $0.role == .app }
        let debugProviders = prepared.filter { $0.role == .dSYM }

        var imageMatches: [ImageMatch] = []
        var imageResults: [CrashSymbolicatedImage] = []
        for (position, image) in crash.images.prefix(maximumImages).enumerated() {
            let match = match(
                image: image,
                imagePosition: position,
                imageProviders: imageProviders,
                debugProviders: debugProviders
            )
            imageMatches.append(match)
            let validationProvider = match.imageArtifact ?? match.debugArtifact
            let validation = validationProvider.flatMap { artifact in
                artifact.slice.flatMap { slice in
                    runtimeValidation(image: image, slice: slice)
                }
            }
            imageResults.append(
                CrashSymbolicatedImage(
                    imageIndex: image.imageIndex ?? position,
                    name: image.name,
                    uuid: image.normalizedUUID,
                    rawUUID: image.normalizedUUID == image.uuid ? nil : image.uuid,
                    architecture: image.architecture,
                    matchStatus: match.status,
                    artifactPath: match.imageArtifact?.artifact.binaryPath,
                    debugArtifactPath: match.debugArtifact?.artifact.binaryPath,
                    embeddedDebugProvider: match.imageArtifact?.slice?.hasEmbeddedDebugInfo ?? false,
                    preferredTextAddress: validation.map { hex($0.preferredTextAddress) },
                    runtimeBase: validation.flatMap { $0.runtimeBase.map(hex) },
                    slide: validation.flatMap { $0.slide.map(String.init) },
                    diagnostic: match.diagnostic
                )
            )
        }

        var frameResults: [CrashSymbolicatedFrame] = []
        var pending: [PendingFrame] = []
        var batches: [BatchKey: [PendingFrame]] = [:]
        var unmatchedFrameCount = 0
        var observedFramePosition = 0
        for thread in crash.threads.prefix(maximumThreads) {
            for frame in thread.frames {
                guard observedFramePosition < maximumFrames else { break }
                let resultIndex = frameResults.count
                observedFramePosition += 1
                guard let match = imageMatch(for: frame, crash: crash, matches: imageMatches) else {
                    unmatchedFrameCount += 1
                    frameResults.append(makeFrame(
                        threadID: thread.id,
                        frame: frame,
                        status: .missingImageIdentity,
                        matchStatus: .missingCrashIdentity,
                        diagnostic: "Crash frame has no resolvable image identity."
                    ))
                    continue
                }
                guard match.status == .matched,
                      let provider = match.imageArtifact ?? match.debugArtifact,
                      let slice = provider.slice else {
                    unmatchedFrameCount += 1
                    frameResults.append(makeFrame(
                        threadID: thread.id,
                        frame: frame,
                        status: frameStatus(for: match.status),
                        matchStatus: match.status,
                        artifactPath: (match.imageArtifact ?? match.debugArtifact)?.artifact.binaryPath,
                        diagnostic: match.diagnostic ?? "Crash image did not match one unique executable artifact."
                    ))
                    continue
                }
                let addressParts: AddressParts
                switch resolveAddress(frame: frame, image: match.image) {
                case .success(let resolved):
                    addressParts = resolved
                case .failure(let status, let diagnostic):
                    frameResults.append(makeFrame(
                        threadID: thread.id,
                        frame: frame,
                        status: status,
                        matchStatus: match.status,
                        artifactPath: provider.artifact.binaryPath,
                        diagnostic: diagnostic
                    ))
                    continue
                }
                do {
                    let validation = try SymbolicationService.validateAddress(
                        address: addressParts.absolute,
                        loadAddress: addressParts.base,
                        slice: slice
                    )
                    guard let base = addressParts.base else {
                        throw SymbolicationError.invalidLoadAddress
                    }
                    let outputPath = match.debugArtifact?.layout.resolvedBinaryPath
                        ?? provider.layout.resolvedBinaryPath
                    let batchKey = BatchKey(
                        path: outputPath,
                        architecture: slice.architecture.name,
                        loadAddress: base
                    )
                    let item = PendingFrame(
                        resultIndex: resultIndex,
                        frame: frame,
                        imageMatch: match,
                        resolvedAddress: addressParts.absolute,
                        validation: validation,
                        toolPath: outputPath,
                        debugAvailable: match.debugArtifact != nil
                            || match.imageArtifact?.slice?.hasEmbeddedDebugInfo == true,
                        groupKey: batchKey
                    )
                    pending.append(item)
                    batches[batchKey, default: []].append(item)
                    frameResults.append(makeFrame(
                        threadID: thread.id,
                        frame: frame,
                        status: .budgetExceeded,
                        matchStatus: match.status,
                        artifactPath: outputPath,
                        resolvedAddress: hex(addressParts.absolute),
                        diagnostic: nil
                    ))
                } catch SymbolicationError.invalidLoadAddress {
                    frameResults.append(makeFrame(
                        threadID: thread.id,
                        frame: frame,
                        status: .invalidLoadAddress,
                        matchStatus: match.status,
                        artifactPath: provider.artifact.binaryPath,
                        diagnostic: "Crash image base cannot be used to derive a checked Mach-O slide."
                    ))
                } catch {
                    frameResults.append(makeFrame(
                        threadID: thread.id,
                        frame: frame,
                        status: .addressOutOfRange,
                        matchStatus: match.status,
                        artifactPath: provider.artifact.binaryPath,
                        diagnostic: String(describing: error)
                    ))
                }
            }
        }
        _ = pending

        let orderedBatches = batches.keys.sorted { left, right in
            if left.path != right.path { return left.path < right.path }
            if left.architecture != right.architecture { return left.architecture < right.architecture }
            return left.loadAddress < right.loadAddress
        }
        var invocationCount = 0
        for batchKey in orderedBatches {
            let items = batches[batchKey] ?? []
            guard invocationCount < maximumAtosInvocations else {
                for item in items {
                    frameResults[item.resultIndex] = update(
                        frameResults[item.resultIndex],
                        status: .budgetExceeded,
                        diagnostic: "atos invocation limit of 32 was reached."
                    )
                }
                continue
            }
            let elapsed = clock.now() - started
            let remaining = maximumCumulativeSeconds - elapsed
            guard remaining > 0 else {
                for item in items {
                    frameResults[item.resultIndex] = update(
                        frameResults[item.resultIndex],
                        status: .budgetExceeded,
                        diagnostic: "symbolication cumulative deadline of 30 seconds was reached."
                    )
                }
                continue
            }
            var revalidatedProviders: [String: Bool] = [:]
            var providersAreCurrent = true
            for item in items {
                // A batch may contain up to 2,048 frames for the same image.
                // Cache by canonical payload path so SHA-256/stat validation
                // happens once per selected image/debug provider, while still
                // checking both roles when they are distinct.
                let identities = [
                    item.imageMatch.imageArtifact?.layout.fileIdentity,
                    item.imageMatch.debugArtifact?.layout.fileIdentity,
                ].compactMap { $0 }
                if identities.isEmpty {
                    providersAreCurrent = false
                    continue
                }
                for identity in identities {
                    let key = identity.canonicalPath
                    let isCurrent: Bool
                    if let cached = revalidatedProviders[key] {
                        isCurrent = cached
                    } else {
                        isCurrent = AppleArtifactLayoutResolver.revalidate(identity)
                        revalidatedProviders[key] = isCurrent
                    }
                    providersAreCurrent = providersAreCurrent && isCurrent
                }
            }
            guard providersAreCurrent else {
                for item in items {
                    frameResults[item.resultIndex] = update(
                        frameResults[item.resultIndex],
                        status: .artifactChanged,
                        diagnostic: "symbolication artifact changed after identity inspection."
                    )
                }
                continue
            }

            let timeoutMilliseconds = min(maximumBatchMilliseconds, max(1, Int(ceil(remaining * 1_000))))
            var arguments = ["atos", "-o", batchKey.path, "-arch", batchKey.architecture, "-l", hex(batchKey.loadAddress)]
            arguments.append(contentsOf: items.map { hex($0.resolvedAddress) })
            invocationCount += 1
            do {
                let result = try SymbolicationService.runTool(
                    arguments: arguments,
                    timeoutMilliseconds: timeoutMilliseconds,
                    runner: toolRunner
                )
                if clock.now() - started > maximumCumulativeSeconds {
                    for item in items {
                        frameResults[item.resultIndex] = update(
                            frameResults[item.resultIndex],
                            status: .budgetExceeded,
                            diagnostic: "atos returned after the 30 second cumulative deadline."
                        )
                    }
                    continue
                }
                let lines = result.stdout.split(whereSeparator: { $0.isNewline }).map(String.init)
                for (offset, item) in items.enumerated() {
                    guard result.terminationStatus == 0 else {
                        let diagnostic = diagnostics.append(result.stderr.isEmpty ? result.stdout : result.stderr)
                        frameResults[item.resultIndex] = update(
                            frameResults[item.resultIndex],
                            status: .toolFailure,
                            diagnostic: diagnostic ?? "atos returned a non-zero status."
                        )
                        continue
                    }
                    guard offset < lines.count else {
                        frameResults[item.resultIndex] = update(
                            frameResults[item.resultIndex],
                            status: .unresolved,
                            quality: "unresolved",
                            diagnostic: "atos returned fewer lines than requested addresses."
                        )
                        continue
                    }
                    let output: SymbolicationOutput = SymbolicationService.classifyAtosOutput(
                        lines[offset],
                        requestedAddress: hex(item.resolvedAddress)
                    )
                    let status: CrashFrameSymbolicationStatus
                    if output.status == .resolvedSourceLine, item.debugAvailable {
                        status = .resolvedSourceLine
                    } else if output.status == .resolvedSourceLine {
                        status = .missingDebugProvider
                    } else if item.debugAvailable {
                        status = output.status == .resolvedSymbolOnly ? .resolvedSymbolOnly : .unresolved
                    } else if output.status == .resolvedSymbolOnly {
                        status = .missingDebugProvider
                    } else {
                        status = .unresolved
                    }
                    let diagnostic = diagnostics.append(output.diagnostic)
                    frameResults[item.resultIndex] = update(
                        frameResults[item.resultIndex],
                        status: status,
                        symbol: output.symbol.isEmpty ? nil : output.symbol,
                        quality: output.status.rawValue,
                        sourceFile: output.sourceFile,
                        sourceLine: output.sourceLine,
                        diagnostic: diagnostic
                    )
                }
            } catch {
                let diagnostic = diagnostics.append(String(describing: error))
                for item in items {
                    frameResults[item.resultIndex] = update(
                        frameResults[item.resultIndex],
                        status: .toolFailure,
                        diagnostic: diagnostic ?? "bounded atos invocation failed."
                    )
                }
            }
        }

        let returnedFrames = frameResults
        let hasSuccessfulFrame = returnedFrames.contains {
            $0.status == .resolvedSourceLine || $0.status == .resolvedSymbolOnly
        }
        let hasFailure = returnedFrames.contains {
            $0.status != .resolvedSourceLine && $0.status != .resolvedSymbolOnly
        }
        let truncated = crash.truncated || crash.images.count > maximumImages
            || crash.threads.count > maximumThreads || crash.observedFrameCount > maximumFrames
            || orderedBatches.count > maximumAtosInvocations || diagnostics.truncated
        let outcome: CrashSymbolicationOutcome
        if hasSuccessfulFrame, !hasFailure, !truncated {
            outcome = .complete
        } else if hasSuccessfulFrame {
            outcome = .partial
        } else {
            outcome = .failed
        }
        return CrashSymbolicationReport(
            crash: crash,
            artifacts: artifacts,
            frames: returnedFrames,
            unmatchedFrameCount: unmatchedFrameCount,
            images: imageResults,
            outcome: outcome,
            observedImageCount: crash.observedImageCount,
            returnedImageCount: imageResults.count,
            observedThreadCount: crash.observedThreadCount,
            returnedThreadCount: min(crash.threads.count, maximumThreads),
            observedFrameCount: crash.observedFrameCount,
            returnedFrameCount: returnedFrames.count,
            atosInvocationCount: invocationCount,
            diagnostics: diagnostics.values,
            diagnosticsTruncated: diagnostics.truncated,
            truncated: truncated
        )
    }

    private static func prepare(
        artifact: CrashSymbolicationArtifact,
        diagnostics: inout Diagnostics
    ) -> [PreparedArtifact] {
        var values: [PreparedArtifact] = []
        do {
            let layout = try AppleArtifactLayoutResolver.resolve(path: artifact.binaryPath)
            let slice = layout.slice(for: artifact.architecture)
            if slice == nil {
                _ = diagnostics.append("artifact \(artifact.binaryPath) has no exact \(artifact.architecture) slice.")
            }
            values.append(PreparedArtifact(
                artifact: artifact,
                layout: layout,
                slice: slice,
                role: layout.kind
            ))
        } catch {
            _ = diagnostics.append("artifact \(artifact.binaryPath): \(error.localizedDescription)")
        }
        if let dSYMPath = artifact.dSYMPath {
            let debugArtifact = CrashSymbolicationArtifact(
                binaryPath: dSYMPath,
                architecture: artifact.architecture
            )
            do {
                let layout = try AppleArtifactLayoutResolver.resolve(path: dSYMPath)
                values.append(PreparedArtifact(
                    artifact: debugArtifact,
                    layout: layout,
                    slice: layout.slice(for: artifact.architecture),
                    role: layout.kind
                ))
            } catch {
                _ = diagnostics.append("debug artifact \(dSYMPath): \(error.localizedDescription)")
            }
        }
        return values
    }

    private static func match(
        image: CrashImage,
        imagePosition: Int,
        imageProviders: [PreparedArtifact],
        debugProviders: [PreparedArtifact]
    ) -> ImageMatch {
        guard let uuid = image.normalizedUUID,
              let architecture = image.architecture, !architecture.isEmpty else {
            return ImageMatch(
                status: .missingCrashIdentity,
                image: image,
                imageArtifact: nil,
                debugArtifact: nil,
                diagnostic: "Crash image is missing a canonical UUID or exact architecture."
            )
        }
        let key = "\(uuid)|\(architecture)"
        let exactImages = distinct(imageProviders.filter { $0.key == key })
        let exactDebug = distinct(debugProviders.filter { $0.key == key })
        let allProviders = imageProviders + debugProviders
        let sameUUID = allProviders.contains { artifact in
                guard let slice = artifact.slice else { return false }
                return slice.uuid == uuid
            }
        let sameArchitecture = allProviders.contains { artifact in
                artifact.slice?.architecture.name == architecture
            }
        if exactImages.count > 1 {
            return ImageMatch(
                status: .ambiguousProvider,
                image: image,
                imageArtifact: nil,
                debugArtifact: nil,
                diagnostic: "Multiple distinct executable providers match this crash UUID and architecture."
            )
        }
        if exactDebug.count > 1 {
            return ImageMatch(
                status: .ambiguousProvider,
                image: image,
                imageArtifact: exactImages.first,
                debugArtifact: nil,
                diagnostic: "Multiple distinct dSYM providers match this crash UUID and architecture."
            )
        }
        if exactImages.isEmpty, let debugArtifact = exactDebug.first {
            _ = imagePosition
            return ImageMatch(
                status: .matched,
                image: image,
                imageArtifact: nil,
                debugArtifact: debugArtifact,
                diagnostic: "dSYM-only identity/provider match; no executable/app image provider was supplied."
            )
        }
        guard let imageArtifact = exactImages.first else {
            let status: CrashImageMatchStatus
            let diagnostic: String
            if sameUUID {
                status = .wrongArchitecture
                diagnostic = "Crash UUID matches an artifact, but its exact CPU subtype architecture differs."
            } else if sameArchitecture {
                status = .wrongUUID
                diagnostic = "Crash architecture matches an artifact, but its normalized UUID differs."
            } else {
                status = .noMatchingArtifact
                diagnostic = "No executable/app or dSYM artifact matched the crash UUID and architecture."
            }
            return ImageMatch(status: status, image: image, imageArtifact: nil, debugArtifact: nil, diagnostic: diagnostic)
        }
        let debugArtifact = exactDebug.first
        let diagnostic = debugArtifact == nil
            ? "Executable identity matched; no embedded or explicit dSYM provider was supplied."
            : nil
        _ = imagePosition
        return ImageMatch(
            status: .matched,
            image: image,
            imageArtifact: imageArtifact,
            debugArtifact: debugArtifact,
            diagnostic: diagnostic
        )
    }

    private static func distinct(_ artifacts: [PreparedArtifact]) -> [PreparedArtifact] {
        var seen = Set<String>()
        return artifacts.filter { artifact in
            let contentIdentity = artifact.layout.fileIdentity.sha256
            guard seen.insert(contentIdentity).inserted else { return false }
            return true
        }
    }

    private static func imageMatch(
        for frame: CrashFrame,
        crash: CrashReport,
        matches: [ImageMatch]
    ) -> ImageMatch? {
        if let imageIndex = frame.imageIndex {
            if let position = crash.images.firstIndex(where: { $0.imageIndex == imageIndex }) {
                return matches[safe: position]
            }
            if imageIndex >= 0, imageIndex < matches.count {
                return matches[imageIndex]
            }
            return nil
        }
        if crash.format == "crash", let address = parseAddress(frame.address) {
            let candidates = crash.images.enumerated().filter { _, image in
                guard let base = parseAddress(image.baseAddress), let size = imageSize(image),
                      let end = checkedAdd(base, size) else { return false }
                return address >= base && address < end
            }
            guard candidates.count == 1 else { return nil }
            return matches[safe: candidates[0].offset]
        }
        return nil
    }

    private struct AddressParts {
        let absolute: UInt64
        let base: UInt64?
    }

    private enum AddressResolution {
        case success(AddressParts)
        case failure(CrashFrameSymbolicationStatus, String)
    }

    private static func resolveAddress(frame: CrashFrame, image: CrashImage) -> AddressResolution {
        guard let base = parseAddress(image.baseAddress), base > 0 else {
            return .failure(.invalidLoadAddress, "Crash image has a missing, malformed, or zero load address.")
        }
        guard let size = imageSize(image), size > 0,
              let end = checkedAdd(base, size), end > base else {
            return .failure(.invalidLoadAddress, "Crash image has a missing, malformed, or overflowing size/range.")
        }
        if frame.locationKind == .imageRelative {
            guard let offset = parseAddress(frame.imageOffset ?? frame.address) else {
                return .failure(.invalidAddress, "Crash frame image-relative offset is malformed.")
            }
            guard offset < size else {
                return .failure(.addressOutOfRange, "Crash frame image-relative offset is outside the image range.")
            }
            guard let absolute = checkedAdd(base, offset), absolute < end else {
                return .failure(.addressOutOfRange, "Crash frame image-relative address overflowed the image range.")
            }
            return .success(AddressParts(absolute: absolute, base: base))
        }
        guard let absolute = parseAddress(frame.address) else {
            return .failure(.invalidAddress, "Crash frame absolute address is malformed.")
        }
        guard absolute >= base, absolute < end else {
            return .failure(.addressOutOfRange, "Crash frame absolute address is outside the image range.")
        }
        return .success(AddressParts(absolute: absolute, base: base))
    }

    private static func runtimeValidation(image: CrashImage, slice: MachOSliceReport) -> SymbolicationAddressValidation? {
        guard let base = parseAddress(image.baseAddress), base > 0 else { return nil }
        do {
            let preferred = try SymbolicationService.validateAddress(
                address: base,
                loadAddress: base,
                slice: slice
            )
            return preferred
        } catch {
            return nil
        }
    }

    private static func makeFrame(
        threadID: Int,
        frame: CrashFrame,
        status: CrashFrameSymbolicationStatus,
        matchStatus: CrashImageMatchStatus,
        artifactPath: String? = nil,
        resolvedAddress: String? = nil,
        diagnostic: String? = nil
    ) -> CrashSymbolicatedFrame {
        CrashSymbolicatedFrame(
            threadID: threadID,
            frameIndex: frame.index,
            image: frame.image,
            address: frame.address,
            originalSymbol: frame.symbol,
            artifactPath: artifactPath,
            symbol: nil,
            error: diagnostic,
            imageIndex: frame.imageIndex,
            locationKind: frame.locationKind,
            resolvedAddress: resolvedAddress,
            matchStatus: matchStatus,
            status: status,
            diagnostic: diagnostic
        )
    }

    private static func update(
        _ frame: CrashSymbolicatedFrame,
        status: CrashFrameSymbolicationStatus,
        symbol: String? = nil,
        quality: String? = nil,
        sourceFile: String? = nil,
        sourceLine: Int? = nil,
        diagnostic: String? = nil
    ) -> CrashSymbolicatedFrame {
        CrashSymbolicatedFrame(
            threadID: frame.threadID,
            frameIndex: frame.frameIndex,
            image: frame.image,
            address: frame.address,
            originalSymbol: frame.originalSymbol,
            artifactPath: frame.artifactPath,
            symbol: symbol ?? frame.symbol,
            error: diagnostic ?? frame.error,
            imageIndex: frame.imageIndex,
            locationKind: frame.locationKind,
            resolvedAddress: frame.resolvedAddress,
            matchStatus: frame.matchStatus,
            status: status,
            quality: quality ?? frame.quality,
            sourceFile: sourceFile ?? frame.sourceFile,
            sourceLine: sourceLine ?? frame.sourceLine,
            diagnostic: diagnostic ?? frame.diagnostic
        )
    }

    private static func frameStatus(for status: CrashImageMatchStatus) -> CrashFrameSymbolicationStatus {
        switch status {
        case .missingCrashIdentity:
            return .missingImageIdentity
        case .wrongUUID:
            return .wrongUUID
        case .wrongArchitecture:
            return .wrongArchitecture
        case .noMatchingArtifact:
            return .noMatchingArtifact
        case .ambiguousProvider:
            return .ambiguousProvider
        case .invalidArtifact, .unsupportedArtifact:
            return .invalidAddress
        case .matched:
            return .unresolved
        }
    }

    private static func imageSize(_ image: CrashImage) -> UInt64? {
        if let size = parseAddress(image.size), size > 0 { return size }
        guard let base = parseAddress(image.baseAddress),
              let end = parseAddress(image.endAddress), end > base else { return nil }
        return end - base
    }

    private static func parseAddress(_ value: String?) -> UInt64? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, !normalized.hasPrefix("-") else { return nil }
        if normalized.lowercased().hasPrefix("0x") {
            return UInt64(normalized.dropFirst(2), radix: 16)
        }
        if normalized.range(of: #"[a-fA-F]"#, options: .regularExpression) != nil {
            return UInt64(normalized, radix: 16)
        }
        return UInt64(normalized)
    }

    private static func checkedAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64? {
        lhs.addingReportingOverflow(rhs).overflow ? nil : lhs + rhs
    }

    private static func hex(_ value: UInt64) -> String {
        String(format: "0x%llx", value)
    }
}

public enum CrashReportAnalyzer {
    private static let maximumFileSize = 32 * 1024 * 1024
    private static let maximumHeaderBytes = 64 * 1024
    private static let maximumImages = 256
    private static let maximumThreads = 128
    private static let maximumFrames = 2_048

    public static func inspect(path: String) throws -> CrashReport {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CrashReportError.fileNotFound
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let type = attributes[.type] as? FileAttributeType, type == .typeRegular else {
            throw CrashReportError.notRegularFile
        }
        if let size = attributes[.size] as? NSNumber, size.int64Value > Int64(maximumFileSize) {
            throw CrashReportError.fileTooLarge
        }

        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let leading = String(decoding: data.prefix(maximumHeaderBytes), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if leading.hasPrefix("{") || data.prefix(maximumHeaderBytes).firstIndex(of: 0x7b) != nil {
            return try inspectIPS(path: url.path, data: data)
        }
        if url.pathExtension.lowercased() == "crash" || leading.contains("Process:") {
            return inspectText(path: url.path, text: String(decoding: data, as: UTF8.self))
        }
        throw CrashReportError.unsupportedFormat
    }

    private static func inspectIPS(path: String, data: Data) throws -> CrashReport {
        guard let openBrace = data.prefix(maximumHeaderBytes).firstIndex(of: 0x7b) else {
            throw CrashReportError.invalidJSON
        }
        let json = Data(data[openBrace...])
        guard let root = try JSONSerialization.jsonObject(with: json) as? [String: Any] else {
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
        let threadValues = payload["threads"] as? [[String: Any]] ?? []
        let imageValues = payload["usedImages"] as? [[String: Any]] ?? []
        let parsedThreads = parseIPSthreads(threadValues)
        let images = imageValues.prefix(maximumImages).enumerated().map { position, value in
            parseIPSImage(value, fallbackIndex: position)
        }
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
            threads: parsedThreads.threads,
            images: images,
            fields: scalarFields(payload),
            observedImageCount: imageValues.count,
            observedThreadCount: threadValues.count,
            observedFrameCount: parsedThreads.observedFrameCount,
            truncated: imageValues.count > maximumImages || threadValues.count > maximumThreads
                || parsedThreads.truncated
        )
    }

    private static func inspectText(path: String, text: String) -> CrashReport {
        let fields = parseTextFields(text: text)
        let parsedImages = parseTextImages(text: text)
        let process = fields["Process"].map(parseProcess)
        let crashedThread = fields["Triggered by Thread"].flatMap(Int.init)
        let parsedThreads = parseTextThreads(text: text, images: parsedImages.images)
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
            threads: parsedThreads.threads,
            images: parsedImages.images,
            fields: fields,
            observedImageCount: parsedImages.observedCount,
            observedThreadCount: parsedThreads.observedThreadCount,
            observedFrameCount: parsedThreads.observedFrameCount,
            truncated: parsedImages.truncated || parsedThreads.truncated
        )
    }

    private static func parseIPSthreads(_ values: [[String: Any]]) -> (threads: [CrashThread], observedFrameCount: Int, truncated: Bool) {
        var threads: [CrashThread] = []
        var observedFrames = 0
        var truncated = values.count > maximumThreads
        var remaining = maximumFrames
        for value in values.prefix(maximumThreads) {
            guard let id = firstInt(value, keys: ["id", "threadID", "threadId"]) else { continue }
            let valuesForThread = value["frames"] as? [[String: Any]] ?? []
            observedFrames += valuesForThread.count
            if valuesForThread.count > remaining { truncated = true }
            let frames = valuesForThread.prefix(remaining).enumerated().map { index, frame in
                let imageOffset = firstString(frame, keys: ["imageOffset", "offset"])
                let imageIndex = firstInt(frame, keys: ["imageIndex"])
                let address = firstString(frame, keys: ["address", "symbolLocation"])
                return CrashFrame(
                    index: index,
                    image: firstString(frame, keys: ["image", "imageName"]),
                    address: address ?? imageOffset,
                    symbol: firstString(frame, keys: ["symbol", "function"]),
                    imageIndex: imageIndex,
                    imageOffset: imageOffset,
                    locationKind: imageOffset == nil ? .absolute : .imageRelative
                )
            }
            remaining -= frames.count
            threads.append(CrashThread(
                id: id,
                name: firstString(value, keys: ["name", "threadName"]),
                crashed: firstBool(value, keys: ["triggered", "crashed", "faulting"]) ?? false,
                frames: frames
            ))
        }
        if values.count > maximumThreads || remaining == 0 && observedFrames > maximumFrames {
            truncated = true
        }
        return (threads, observedFrames, truncated)
    }

    private static func parseIPSImage(_ value: [String: Any], fallbackIndex: Int) -> CrashImage {
        let base = firstString(value, keys: ["base", "baseAddress", "loadAddress"])
        let end = firstString(value, keys: ["end", "endAddress"])
        let size = firstString(value, keys: ["size", "imageSize"])
        return CrashImage(
            name: firstString(value, keys: ["name", "imageName"]),
            uuid: firstString(value, keys: ["uuid", "imageUUID"]),
            path: firstString(value, keys: ["path"]),
            baseAddress: base,
            imageIndex: firstInt(value, keys: ["imageIndex"]) ?? fallbackIndex,
            architecture: firstString(value, keys: ["arch", "architecture"]),
            size: size,
            endAddress: end
        )
    }

    private static func parseTextFields(text: String) -> [String: String] {
        var fields: [String: String] = [:]
        text.enumerateLines { line, _ in
            guard fields.count < 256,
                  let separator = line.firstIndex(of: ":") else { return }
            let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: separator)...])
                .trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !value.isEmpty else { return }
            let boundedKey = String(decoding: Array(key.utf8.prefix(512)), as: UTF8.self)
            let boundedValue = String(decoding: Array(value.utf8.prefix(4 * 1024)), as: UTF8.self)
            fields[boundedKey] = boundedValue
        }
        return fields
    }

    private static func parseTextImages(text: String) -> (images: [CrashImage], observedCount: Int, truncated: Bool) {
        var images: [CrashImage] = []
        var observedCount = 0
        var truncated = false
        var inImages = false
        text.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !inImages {
                inImages = trimmed == "Binary Images:"
                return
            }
            let parts = trimmed.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 6,
                  parts[1] == "-",
                  let uuidIndex = parts.firstIndex(where: { $0.first == "<" && $0.last == ">" }),
                  uuidIndex >= 3 else { return }
            observedCount += 1
            let uuid = String(parts[uuidIndex]).trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            let base = String(parts[0])
            let end = String(parts[2])
            let size: String?
            if let baseValue = parseNumeric(base), let endValue = parseNumeric(end), endValue > baseValue {
                size = hex(endValue - baseValue)
            } else {
                size = nil
            }
            let path = uuidIndex + 1 < parts.count ? parts[(uuidIndex + 1)...].map(String.init).joined(separator: " ") : nil
            let name = String(parts[3]).trimmingCharacters(in: CharacterSet(charactersIn: "+"))
            if images.count < maximumImages {
                images.append(CrashImage(
                    name: name.isEmpty ? path.map { URL(fileURLWithPath: $0).lastPathComponent } : name,
                    uuid: uuid,
                    path: path,
                    baseAddress: base,
                    imageIndex: images.count,
                    architecture: uuidIndex > 0 ? String(parts[uuidIndex - 1]) : nil,
                    size: size,
                    endAddress: end
                ))
            } else {
                truncated = true
            }
        }
        return (images, observedCount, truncated)
    }

    private static func parseTextThreads(text: String, images: [CrashImage]) -> (threads: [CrashThread], observedThreadCount: Int, observedFrameCount: Int, truncated: Bool) {
        var threads: [CrashThread] = []
        var currentID: Int?
        var currentName: String?
        var currentCrashed = false
        var currentFrames: [CrashFrame] = []
        var currentAccepted = false
        var observedThreadCount = 0
        var observedFrames = 0
        var returnedFrames = 0
        var truncated = false

        func flush() {
            guard let currentID else { return }
            if currentAccepted {
                threads.append(CrashThread(id: currentID, name: currentName, crashed: currentCrashed, frames: currentFrames))
            }
        }

        text.enumerateLines { line, stop in
            if line.hasPrefix("Thread ") {
                flush()
                observedThreadCount += 1
                if observedThreadCount > maximumThreads { truncated = true }
                let rest = line.dropFirst("Thread ".count)
                let idString = rest.prefix { $0.isNumber }
                currentID = Int(idString)
                currentCrashed = line.contains("Crashed")
                currentName = nil
                currentFrames = []
                currentAccepted = observedThreadCount <= maximumThreads
                return
            }
            if line.trimmingCharacters(in: .whitespaces) == "Binary Images:" {
                stop = true
                return
            }
            guard currentID != nil else { return }
            let parts = line.split(maxSplits: 3, whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 3, let index = Int(parts[0]) else { return }
            observedFrames += 1
            guard currentAccepted else { return }
            guard returnedFrames < maximumFrames else {
                truncated = true
                return
            }
            let address = String(parts[2])
            let imageIndex = parseNumeric(address).flatMap { addressValue in
                let candidates = images.enumerated().filter { _, image in
                    guard let base = parseNumeric(image.baseAddress), let size = imageSize(image),
                          let end = checkedAdd(base, size) else { return false }
                    return addressValue >= base && addressValue < end
                }
                return candidates.count == 1 ? candidates[0].offset : nil
            }
            currentFrames.append(CrashFrame(
                index: index,
                image: String(parts[1]),
                address: address,
                symbol: parts.count == 4 ? String(parts[3]) : nil,
                imageIndex: imageIndex,
                locationKind: .absolute
            ))
            returnedFrames += 1
        }
        flush()
        return (
            threads: Array(threads.prefix(maximumThreads)),
            observedThreadCount: observedThreadCount,
            observedFrameCount: observedFrames,
            truncated: truncated || observedFrames > maximumFrames
        )
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
        var result: [String: String] = [:]
        for key in dictionary.keys.sorted().prefix(256) {
            guard let value = dictionary[key] else { continue }
            if let value = value as? String {
                result[key] = String(decoding: Array(value.utf8.prefix(4 * 1024)), as: UTF8.self)
            } else if let value = value as? NSNumber {
                result[key] = value.stringValue
            }
        }
        return result
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

    private static func parseNumeric(_ value: String?) -> UInt64? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.lowercased().hasPrefix("0x") {
            return UInt64(normalized.dropFirst(2), radix: 16)
        }
        if normalized.range(of: #"[a-fA-F]"#, options: .regularExpression) != nil {
            return UInt64(normalized, radix: 16)
        }
        return UInt64(normalized)
    }

    private static func imageSize(_ image: CrashImage) -> UInt64? {
        if let size = parseNumeric(image.size), size > 0 { return size }
        guard let base = parseNumeric(image.baseAddress), let end = parseNumeric(image.endAddress), end > base else { return nil }
        return end - base
    }

    private static func checkedAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64? {
        lhs.addingReportingOverflow(rhs).overflow ? nil : lhs + rhs
    }

    private static func hex(_ value: UInt64) -> String {
        String(format: "0x%llx", value)
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
