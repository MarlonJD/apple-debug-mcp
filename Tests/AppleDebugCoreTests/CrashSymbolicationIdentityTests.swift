// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import XCTest
@testable import AppleDebugCore

final class CrashSymbolicationIdentityTests: XCTestCase {
    func testTextBinaryImagesExactIdentityAndSourceLineResolution() throws {
        let context = try fixtureContext()
        let crash = try write(
            textCrash(context: context, address: context.address),
            suffix: "exact.crash"
        )
        let dsym = try makeDSYM(for: context.binary)
        defer {
            try? FileManager.default.removeItem(at: crash)
            try? FileManager.default.removeItem(at: dsym)
        }
        let recorder = ToolRecorder()

        let report = try CrashSymbolicationService.symbolize(
            path: crash.path,
            artifacts: [CrashSymbolicationArtifact(
                imageName: "wrong-name-is-ignored",
                binaryPath: context.binary.path,
                architecture: context.architecture
            ), CrashSymbolicationArtifact(binaryPath: dsym.path, architecture: context.architecture)],
            toolRunner: fakeRunner(recorder, output: "fixture_symbol (in Fixture) (fixture.c:42)")
        )

        XCTAssertEqual(report.outcome, .complete)
        XCTAssertEqual(report.images.first?.matchStatus, .matched)
        XCTAssertEqual(report.frames.first?.status, .resolvedSourceLine)
        XCTAssertEqual(report.frames.first?.sourceLine, 42)
        XCTAssertEqual(report.frames.first?.matchStatus, .matched)
        XCTAssertEqual(recorder.arguments.count, 1)
        XCTAssertEqual(recorder.arguments.first?.first, "atos")
    }

    func testIPSHeaderPayloadDecimalImageIndexAndOffsetResolve() throws {
        let context = try fixtureContext()
        let payload: [String: Any] = [
            "name": "Fixture",
            "faultingThread": 0,
            "usedImages": [[
                "imageIndex": 7,
                "name": "Fixture",
                "uuid": context.uuid.replacingOccurrences(of: "-", with: ""),
                "arch": context.architecture,
                "base": String(context.base),
                "size": String(context.size),
            ]],
            "threads": [[
                "id": 0,
                "triggered": true,
                "frames": [[
                    "imageIndex": 7,
                    "imageOffset": String(context.address - context.base),
                    "symbol": "fixture_symbol",
                ]],
            ]],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let crash = try write("Incident Identifier: header\n\n" + String(decoding: data, as: UTF8.self), suffix: "header.ips")
        let dsym = try makeDSYM(for: context.binary)
        defer {
            try? FileManager.default.removeItem(at: crash)
            try? FileManager.default.removeItem(at: dsym)
        }
        let recorder = ToolRecorder()

        let inspected = try CrashReportAnalyzer.inspect(path: crash.path)
        XCTAssertEqual(inspected.images.first?.imageIndex, 7)
        XCTAssertEqual(inspected.threads.first?.frames.first?.locationKind, .imageRelative)
        XCTAssertEqual(inspected.threads.first?.frames.first?.imageOffset, String(context.address - context.base))

        let report = try CrashSymbolicationService.symbolize(
            path: crash.path,
            artifacts: [
                CrashSymbolicationArtifact(binaryPath: context.binary.path, architecture: context.architecture),
                CrashSymbolicationArtifact(binaryPath: dsym.path, architecture: context.architecture),
            ],
            toolRunner: fakeRunner(recorder, output: "fixture_symbol (in Fixture) (fixture.c:42)")
        )
        XCTAssertEqual(report.outcome, .complete)
        XCTAssertEqual(report.images.first?.uuid, context.uuid)
        XCTAssertNotEqual(report.images.first?.rawUUID, context.uuid)
        XCTAssertEqual(report.frames.first?.resolvedAddress, hex(context.address))
        XCTAssertEqual(report.frames.first?.status, .resolvedSourceLine)
    }

    func testDSYMProviderIsComplementaryToMatchingExecutable() throws {
        let context = try fixtureContext()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-crash-dsym-\(UUID().uuidString).dSYM")
        let dwarf = root.appendingPathComponent("Contents/Resources/DWARF")
        try FileManager.default.createDirectory(at: dwarf, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: context.binary, to: dwarf.appendingPathComponent("Fixture"))
        defer { try? FileManager.default.removeItem(at: root) }
        let crash = try write(textCrash(context: context, address: context.address), suffix: "dsym.crash")
        defer { try? FileManager.default.removeItem(at: crash) }
        let recorder = ToolRecorder()

        let report = try CrashSymbolicationService.symbolize(
            path: crash.path,
            artifacts: [
                CrashSymbolicationArtifact(binaryPath: context.binary.path, architecture: context.architecture),
                CrashSymbolicationArtifact(binaryPath: root.path, architecture: context.architecture),
            ],
            toolRunner: fakeRunner(recorder, output: "fixture_symbol (in Fixture) (fixture.c:42)")
        )

        XCTAssertEqual(report.images.first?.matchStatus, .matched)
        XCTAssertNotNil(report.images.first?.debugArtifactPath)
        XCTAssertEqual(report.frames.first?.status, .resolvedSourceLine)
        XCTAssertTrue(
            recorder.arguments.first?.contains(where: { $0.hasSuffix("/Contents/Resources/DWARF/Fixture") }) == true,
            "atos arguments: \(recorder.arguments)"
        )
    }

    func testDSYMOnlyProviderCanSupplyCrashIdentityAndSymbolProvider() throws {
        let context = try fixtureContext()
        let dsym = try makeDSYM(for: context.binary)
        let crash = try write(textCrash(context: context, address: context.address), suffix: "dsym-only.crash")
        defer {
            try? FileManager.default.removeItem(at: dsym)
            try? FileManager.default.removeItem(at: crash)
        }
        let recorder = ToolRecorder()

        let report = try CrashSymbolicationService.symbolize(
            path: crash.path,
            artifacts: [CrashSymbolicationArtifact(binaryPath: dsym.path, architecture: context.architecture)],
            toolRunner: fakeRunner(recorder, output: "fixture_symbol (in Fixture) (fixture.c:42)")
        )

        XCTAssertEqual(report.images.first?.matchStatus, .matched)
        XCTAssertNil(report.images.first?.artifactPath)
        XCTAssertNotNil(report.images.first?.debugArtifactPath)
        XCTAssertEqual(report.frames.first?.status, .resolvedSourceLine)
        XCTAssertEqual(report.outcome, .complete)
        XCTAssertEqual(recorder.arguments.count, 1)
    }

    func testWrongUUIDWrongArchitectureAndAmbiguousProvidersNeverInvokeAtos() throws {
        let context = try fixtureContext()
        let wrongUUIDCrash = try write(
            textCrash(context: context, uuid: "abcdefabcdefabcdefabcdefabcdefab"),
            suffix: "wrong-uuid.crash"
        )
        let alternateArchitecture = context.architecture == "arm64" ? "arm64e" : "arm64"
        let wrongArchitectureCrash = try write(
            textCrash(context: context, architecture: alternateArchitecture),
            suffix: "wrong-architecture.crash"
        )
        defer {
            try? FileManager.default.removeItem(at: wrongUUIDCrash)
            try? FileManager.default.removeItem(at: wrongArchitectureCrash)
        }
        let recorder = ToolRecorder()
        let artifact = CrashSymbolicationArtifact(binaryPath: context.binary.path, architecture: context.architecture)

        let wrongUUID = try CrashSymbolicationService.symbolize(
            path: wrongUUIDCrash.path,
            artifacts: [artifact],
            toolRunner: fakeRunner(recorder, output: "must-not-run")
        )
        XCTAssertEqual(wrongUUID.images.first?.matchStatus, .wrongUUID)
        XCTAssertEqual(wrongUUID.frames.first?.status, .wrongUUID)

        let wrongArchitecture = try CrashSymbolicationService.symbolize(
            path: wrongArchitectureCrash.path,
            artifacts: [artifact],
            toolRunner: fakeRunner(recorder, output: "must-not-run")
        )
        XCTAssertEqual(wrongArchitecture.images.first?.matchStatus, .wrongArchitecture)
        XCTAssertEqual(wrongArchitecture.frames.first?.status, .wrongArchitecture)

        let firstCopy = FileManager.default.temporaryDirectory.appendingPathComponent("fixture-copy-a-\(UUID().uuidString)")
        let secondCopy = FileManager.default.temporaryDirectory.appendingPathComponent("fixture-copy-b-\(UUID().uuidString)")
        let dsym = try makeDSYM(for: context.binary)
        let exactCrash = try write(
            textCrash(context: context, address: context.address),
            suffix: "ambiguous.crash"
        )
        try FileManager.default.copyItem(at: context.binary, to: firstCopy)
        try FileManager.default.copyItem(at: context.binary, to: secondCopy)
        defer {
            try? FileManager.default.removeItem(at: exactCrash)
            try? FileManager.default.removeItem(at: firstCopy)
            try? FileManager.default.removeItem(at: secondCopy)
            try? FileManager.default.removeItem(at: dsym)
        }
        let dSYMOnlyWrongUUID = try CrashSymbolicationService.symbolize(
            path: wrongUUIDCrash.path,
            artifacts: [CrashSymbolicationArtifact(binaryPath: dsym.path, architecture: context.architecture)],
            toolRunner: fakeRunner(recorder, output: "must-not-run")
        )
        XCTAssertEqual(dSYMOnlyWrongUUID.images.first?.matchStatus, .wrongUUID)
        XCTAssertEqual(recorder.arguments.count, 0)
        let dSYMOnlyWrongArchitecture = try CrashSymbolicationService.symbolize(
            path: wrongArchitectureCrash.path,
            artifacts: [CrashSymbolicationArtifact(binaryPath: dsym.path, architecture: context.architecture)],
            toolRunner: fakeRunner(recorder, output: "must-not-run")
        )
        XCTAssertEqual(dSYMOnlyWrongArchitecture.images.first?.matchStatus, .wrongArchitecture)
        XCTAssertEqual(recorder.arguments.count, 0)
        let deduplicated = try CrashSymbolicationService.symbolize(
            path: exactCrash.path,
            artifacts: [
                CrashSymbolicationArtifact(binaryPath: context.binary.path, architecture: context.architecture),
                CrashSymbolicationArtifact(binaryPath: firstCopy.path, architecture: context.architecture),
                CrashSymbolicationArtifact(binaryPath: secondCopy.path, architecture: context.architecture),
            ],
            toolRunner: fakeRunner(recorder, output: "fixture_symbol (in Fixture)")
        )
        XCTAssertEqual(deduplicated.images.first?.matchStatus, .matched)
        XCTAssertEqual(deduplicated.frames.first?.status, .missingDebugProvider)
        XCTAssertEqual(recorder.arguments.count, 1)
        recorder.arguments.removeAll()
        var modified = try Data(contentsOf: secondCopy)
        modified.append(0)
        try modified.write(to: secondCopy)
        let ambiguous = try CrashSymbolicationService.symbolize(
            path: exactCrash.path,
            artifacts: [
                CrashSymbolicationArtifact(binaryPath: context.binary.path, architecture: context.architecture),
                CrashSymbolicationArtifact(binaryPath: firstCopy.path, architecture: context.architecture),
                CrashSymbolicationArtifact(binaryPath: secondCopy.path, architecture: context.architecture),
            ],
            toolRunner: fakeRunner(recorder, output: "must-not-run")
        )
        XCTAssertEqual(ambiguous.images.first?.matchStatus, .ambiguousProvider)
        XCTAssertEqual(recorder.arguments.count, 0)
    }

    func testMissingDSYMIsTypedAndSymbolOnlyDoesNotClaimCompleteResolution() throws {
        let context = try fixtureContext()
        let crash = try write(textCrash(context: context, address: context.address), suffix: "missing-dsym.crash")
        defer { try? FileManager.default.removeItem(at: crash) }
        let report = try CrashSymbolicationService.symbolize(
            path: crash.path,
            artifacts: [CrashSymbolicationArtifact(binaryPath: context.binary.path, architecture: context.architecture)],
            toolRunner: fakeRunner(ToolRecorder(), output: "fixture_symbol (in Fixture)")
        )
        XCTAssertEqual(report.images.first?.matchStatus, .matched)
        XCTAssertEqual(report.frames.first?.quality, "resolvedSymbolOnly")
        XCTAssertEqual(report.frames.first?.status, .missingDebugProvider)
        XCTAssertNotEqual(report.outcome, .complete)

        let sourceLineReport = try CrashSymbolicationService.symbolize(
            path: crash.path,
            artifacts: [CrashSymbolicationArtifact(binaryPath: context.binary.path, architecture: context.architecture)],
            toolRunner: fakeRunner(ToolRecorder(), output: "fixture_symbol (in Fixture) (fixture.c:42)")
        )
        XCTAssertEqual(sourceLineReport.frames.first?.quality, "resolvedSourceLine")
        XCTAssertEqual(sourceLineReport.frames.first?.status, .missingDebugProvider)
        XCTAssertEqual(sourceLineReport.frames.first?.sourceLine, 42)
        XCTAssertNotEqual(sourceLineReport.outcome, .complete)
    }

    func testMissingAndOutOfRangeAddressFailuresDoNotInvokeAtos() throws {
        let context = try fixtureContext()
        let missingBase = try write(textCrash(context: context, baseValue: "0x0"), suffix: "missing-base.crash")
        let outOfRange = try write(
            textCrash(
                context: context,
                address: context.base + 0x10_000_000 - 1,
                imageSize: 0x10_000_000
            ),
            suffix: "out-of-range.crash"
        )
        defer {
            try? FileManager.default.removeItem(at: missingBase)
            try? FileManager.default.removeItem(at: outOfRange)
        }
        let recorder = ToolRecorder()
        let artifact = CrashSymbolicationArtifact(binaryPath: context.binary.path, architecture: context.architecture)
        let missing = try CrashSymbolicationService.symbolize(
            path: missingBase.path,
            artifacts: [artifact],
            toolRunner: fakeRunner(recorder, output: "must-not-run")
        )
        let range = try CrashSymbolicationService.symbolize(
            path: outOfRange.path,
            artifacts: [artifact],
            toolRunner: fakeRunner(recorder, output: "must-not-run")
        )
        XCTAssertEqual(missing.frames.first?.status, .invalidLoadAddress)
        XCTAssertEqual(range.frames.first?.status, .addressOutOfRange)
        XCTAssertEqual(recorder.arguments.count, 0)
    }

    func testCumulativeSymbolicationDeadlineRejectsLateBatch() throws {
        let context = try fixtureContext()
        let crash = try write(
            textCrash(context: context, address: context.address),
            suffix: "late-batch.crash"
        )
        defer { try? FileManager.default.removeItem(at: crash) }
        let clockBox = ClockBox()
        let recorder = ToolRecorder()
        let report = try CrashSymbolicationService.symbolize(
            path: crash.path,
            artifacts: [CrashSymbolicationArtifact(binaryPath: context.binary.path, architecture: context.architecture)],
            toolRunner: SymbolicationToolRunner { arguments, timeoutMilliseconds in
                recorder.arguments.append(arguments)
                recorder.timeouts.append(timeoutMilliseconds)
                clockBox.value += 31
                return SymbolicationToolResult(stdout: "fixture_symbol (in Fixture)")
            },
            clock: SymbolicationClock(now: { clockBox.value })
        )
        XCTAssertEqual(recorder.arguments.count, 1)
        XCTAssertLessThanOrEqual(recorder.timeouts.first ?? 0, 5_000)
        XCTAssertEqual(report.frames.first?.status, .budgetExceeded)
        XCTAssertEqual(report.outcome, .failed)
    }

    func testRepeatedDiagnosticsAreDeduplicatedPerFrame() throws {
        let context = try fixtureContext()
        let payload: [String: Any] = [
            "faultingThread": 0,
            "usedImages": [[
                "imageIndex": 0,
                "name": "Fixture",
                "uuid": context.uuid,
                "arch": context.architecture,
                "base": hex(context.base),
                "size": hex(context.size),
            ]],
            "threads": [[
                "id": 0,
                "frames": (0..<4).map { _ in ["imageIndex": 0, "imageOffset": "1"] },
            ]],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let crash = try write(data, suffix: "diagnostics.ips")
        defer { try? FileManager.default.removeItem(at: crash) }
        let diagnostic = String(repeating: "d", count: 4 * 1024)
        let report = try CrashSymbolicationService.symbolize(
            path: crash.path,
            artifacts: [CrashSymbolicationArtifact(binaryPath: context.binary.path, architecture: context.architecture)],
            toolRunner: SymbolicationToolRunner { _, _ in
                SymbolicationToolResult(stdout: "", stderr: diagnostic, terminationStatus: 1)
            }
        )
        XCTAssertEqual(report.atosInvocationCount, 1)
        XCTAssertEqual(report.diagnostics.count, 1)
        XCTAssertTrue(report.frames.allSatisfy { ($0.diagnostic?.utf8.count ?? 0) <= 4 * 1024 })
        XCTAssertTrue(report.frames.dropFirst().allSatisfy { $0.diagnostic?.contains("diagnostic repeated") == true })
    }

    func testChangedImageProviderIsRejectedEvenWhenDSYMProviderIsStable() throws {
        let context = try fixtureContext()
        let mutableBinary = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-changed-image-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: context.binary, to: mutableBinary)
        let mutableContext = FixtureContext(
            binary: mutableBinary,
            uuid: context.uuid,
            architecture: context.architecture,
            base: context.base,
            size: context.size,
            address: context.address
        )
        let dsym = try makeDSYM(for: mutableBinary)
        let crash = try write(textCrash(context: mutableContext, address: context.address), suffix: "changed-image.crash")
        defer {
            try? FileManager.default.removeItem(at: mutableBinary)
            try? FileManager.default.removeItem(at: dsym)
            try? FileManager.default.removeItem(at: crash)
        }
        let mutation = MutationClockBox()
        let recorder = ToolRecorder()
        let report = try CrashSymbolicationService.symbolize(
            path: crash.path,
            artifacts: [
                CrashSymbolicationArtifact(binaryPath: mutableBinary.path, architecture: context.architecture),
                CrashSymbolicationArtifact(binaryPath: dsym.path, architecture: context.architecture),
            ],
            toolRunner: fakeRunner(recorder, output: "must-not-run"),
            clock: SymbolicationClock(now: {
                mutation.count += 1
                if mutation.count == 2 {
                    var data = try! Data(contentsOf: mutableBinary)
                    data.append(0)
                    try! data.write(to: mutableBinary)
                }
                return 0
            })
        )
        XCTAssertEqual(report.frames.first?.status, .artifactChanged)
        XCTAssertEqual(report.atosInvocationCount, 0)
        XCTAssertEqual(recorder.arguments.count, 0)
    }

    private struct FixtureContext {
        let binary: URL
        let uuid: String
        let architecture: String
        let base: UInt64
        let size: UInt64
        let address: UInt64
    }

    private final class ToolRecorder: @unchecked Sendable {
        var arguments: [[String]] = []
        var timeouts: [Int] = []
    }

    private final class ClockBox: @unchecked Sendable {
        var value = 0.0
    }

    private final class MutationClockBox: @unchecked Sendable {
        var count = 0
    }

    private func fixtureContext() throws -> FixtureContext {
        let binary = URL(fileURLWithPath: "/bin/echo")
        let report = try MachOInspector.inspect(path: binary.path)
        guard let slice = report.slices.first,
              let uuid = slice.uuid,
              let base = slice.preferredTextAddress,
              let text = slice.segments.first(where: { $0.name == "__TEXT" }),
              text.virtualSize > 2 else {
            throw XCTSkip("/bin/echo did not expose a usable UUID and __TEXT fixture")
        }
        return FixtureContext(
            binary: binary,
            uuid: uuid,
            architecture: slice.architecture.name,
            base: base,
            size: text.virtualSize,
            address: base + 1
        )
    }

    private func textCrash(
        context: FixtureContext,
        uuid: String? = nil,
        architecture: String? = nil,
        address: UInt64? = nil,
        baseValue: String? = nil,
        imageSize: UInt64? = nil
    ) -> String {
        let selectedBase = baseValue ?? hex(context.base)
        let end = context.base + (imageSize ?? context.size)
        return [
            "Process: Fixture [1]",
            "Triggered by Thread: 0",
            "",
            "Thread 0 Crashed:",
            "0   Fixture \(hex(address ?? context.address)) fixture_symbol + 0",
            "",
            "Binary Images:",
            "\(selectedBase) - \(hex(end)) Fixture \(architecture ?? context.architecture) <\(uuid ?? context.uuid)> \(context.binary.path)",
            "",
        ].joined(separator: "\n")
    }

    private func fakeRunner(_ recorder: ToolRecorder, output: String) -> SymbolicationToolRunner {
        SymbolicationToolRunner { arguments, _ in
            recorder.arguments.append(arguments)
            return SymbolicationToolResult(stdout: output)
        }
    }

    private func makeDSYM(for binary: URL) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-test-\(UUID().uuidString).dSYM")
        let dwarf = root.appendingPathComponent("Contents/Resources/DWARF")
        try FileManager.default.createDirectory(at: dwarf, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: binary, to: dwarf.appendingPathComponent("Fixture"))
        return root
    }

    private func write(_ value: String, suffix: String) throws -> URL {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-\(UUID().uuidString)-\(suffix)")
        try Data(value.utf8).write(to: path)
        return path
    }

    private func write(_ value: Data, suffix: String) throws -> URL {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-\(UUID().uuidString)-\(suffix)")
        try value.write(to: path)
        return path
    }

    private func hex(_ value: UInt64) -> String {
        String(format: "0x%llx", value)
    }
}
