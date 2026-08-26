// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum SimulatorUIError: Error, Equatable, LocalizedError, Sendable {
    case mutationDisabled
    case invalidProject
    case invalidRequest
    case invalidAction
    case unknownSimulator(String)
    case commandFailed(String)
    case attachmentNotFound
    case invalidSnapshot
    case outputTooLarge

    public var errorDescription: String? {
        switch self {
        case .mutationDisabled:
            return "Simulator UI inspection is disabled. Set APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1 for an authorized local workflow."
        case .invalidProject:
            return "UI inspection requires an existing .xcodeproj or .xcworkspace with a UI-test-enabled scheme."
        case .invalidRequest:
            return "Simulator UI inspection request is invalid."
        case .invalidAction:
            return "Simulator UI action is unsupported or missing its required fields."
        case .unknownSimulator(let udid):
            return "Simulator is not in the available inventory: \(udid)"
        case .commandFailed(let message):
            return "Simulator UI test command failed: \(message)"
        case .attachmentNotFound:
            return "The UI test completed without producing an accessibility-tree attachment."
        case .invalidSnapshot:
            return "The UI test attachment is not a valid Apple Debug MCP snapshot."
        case .outputTooLarge:
            return "Simulator UI test output exceeds the configured response limit."
        }
    }
}

public struct SimulatorUIElement: Codable, Equatable, Sendable {
    public let type: UInt
    public let identifier: String
    public let label: String
    public let value: String?
    public let exists: Bool
    public let hittable: Bool
    public let frame: [String: Double]

    public init(
        type: UInt,
        identifier: String,
        label: String,
        value: String?,
        exists: Bool,
        hittable: Bool,
        frame: [String: Double]
    ) {
        self.type = type
        self.identifier = identifier
        self.label = label
        self.value = value
        self.exists = exists
        self.hittable = hittable
        self.frame = frame
    }
}

public struct SimulatorUISnapshot: Codable, Equatable, Sendable {
    public let udid: String
    public let bundleID: String
    public let projectPath: String
    public let scheme: String
    public let debugDescription: String
    public let elements: [SimulatorUIElement]

    public init(
        udid: String,
        bundleID: String,
        projectPath: String,
        scheme: String,
        debugDescription: String,
        elements: [SimulatorUIElement]
    ) {
        self.udid = udid
        self.bundleID = bundleID
        self.projectPath = projectPath
        self.scheme = scheme
        self.debugDescription = debugDescription
        self.elements = elements
    }
}

public struct SimulatorUIActionRequest: Codable, Equatable, Sendable {
    public let action: String
    public let identifier: String?
    public let text: String?
    public let direction: String?
    public let durationSeconds: Double?
    public let scale: Double?
    public let velocity: Double?
    public let x: Double?
    public let y: Double?
    public let endX: Double?
    public let endY: Double?

    public init(
        action: String,
        identifier: String? = nil,
        text: String? = nil,
        direction: String? = nil,
        durationSeconds: Double? = nil,
        scale: Double? = nil,
        velocity: Double? = nil,
        x: Double? = nil,
        y: Double? = nil,
        endX: Double? = nil,
        endY: Double? = nil
    ) {
        self.action = action
        self.identifier = identifier
        self.text = text
        self.direction = direction
        self.durationSeconds = durationSeconds
        self.scale = scale
        self.velocity = velocity
        self.x = x
        self.y = y
        self.endX = endX
        self.endY = endY
    }
}

public struct SimulatorUIActionResult: Codable, Equatable, Sendable {
    public let action: String
    public let snapshot: SimulatorUISnapshot

    public init(action: String, snapshot: SimulatorUISnapshot) {
        self.action = action
        self.snapshot = snapshot
    }
}

public enum SimulatorUIService {
    private static let maximumCommandOutput = 8 * 1024 * 1024
    private static let maximumSnapshotSize = 4 * 1024 * 1024

    public static func snapshot(
        udid: String,
        bundleID: String,
        projectPath: String,
        scheme: String,
        configuration: String = "Debug"
    ) throws -> SimulatorUISnapshot {
        try runProbe(
            udid: udid,
            bundleID: bundleID,
            projectPath: projectPath,
            scheme: scheme,
            configuration: configuration,
            action: nil
        )
    }

    public static func performAction(
        udid: String,
        bundleID: String,
        projectPath: String,
        scheme: String,
        configuration: String = "Debug",
        action: SimulatorUIActionRequest
    ) throws -> SimulatorUIActionResult {
        try validate(action: action)
        let snapshot = try runProbe(
            udid: udid,
            bundleID: bundleID,
            projectPath: projectPath,
            scheme: scheme,
            configuration: configuration,
            action: action
        )
        return SimulatorUIActionResult(action: action.action, snapshot: snapshot)
    }

    public static func installedAppSnapshot(
        udid: String,
        bundleID: String,
        configuration: String = "Debug"
    ) throws -> SimulatorUISnapshot {
        let snapshot = try runGeneratedProbe(
            udid: udid,
            bundleID: bundleID,
            configuration: configuration,
            action: nil
        )
        return generatedSnapshot(snapshot)
    }

    public static func performInstalledAppAction(
        udid: String,
        bundleID: String,
        configuration: String = "Debug",
        action: SimulatorUIActionRequest
    ) throws -> SimulatorUIActionResult {
        try validate(action: action)
        let snapshot = try runGeneratedProbe(
            udid: udid,
            bundleID: bundleID,
            configuration: configuration,
            action: action
        )
        return SimulatorUIActionResult(
            action: action.action,
            snapshot: generatedSnapshot(snapshot)
        )
    }

    private static func runGeneratedProbe(
        udid: String,
        bundleID: String,
        configuration: String,
        action: SimulatorUIActionRequest?
    ) throws -> SimulatorUISnapshot {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-generated-ui-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let projectURL = root.appendingPathComponent("AppleDebugMCPUIProbe.xcodeproj", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try generatedProject.write(
            to: projectURL.appendingPathComponent("project.pbxproj"),
            atomically: true,
            encoding: .utf8
        )
        let actionBase64 = try action.map { try JSONEncoder().encode($0).base64EncodedString() } ?? ""
        let bundleLiteral = try swiftStringLiteral(bundleID)
        let actionLiteral = try swiftStringLiteral(actionBase64)
        let source = generatedSource
            .replacingOccurrences(of: "\"__APPLE_DEBUG_UI_BUNDLE_ID__\"", with: bundleLiteral)
            .replacingOccurrences(of: "\"__APPLE_DEBUG_UI_ACTION_BASE64__\"", with: actionLiteral)
        try source.write(
            to: root.appendingPathComponent("AppleDebugMCPUIProbe.swift"),
            atomically: true,
            encoding: .utf8
        )
        return try runProbe(
            udid: udid,
            bundleID: bundleID,
            projectPath: projectURL.path,
            scheme: "AppleDebugMCPUIProbe",
            configuration: configuration,
            action: action,
            extraBuildSettings: ["APPLE_DEBUG_UI_BUNDLE_ID=\(bundleID)"]
        )
    }

    private static func swiftStringLiteral(_ value: String) throws -> String {
        let data: Data
        do {
            data = try JSONEncoder().encode(value)
        } catch {
            throw SimulatorUIError.invalidRequest
        }
        guard let literal = String(data: data, encoding: .utf8) else {
            throw SimulatorUIError.invalidRequest
        }
        return literal
    }

    private static func generatedSnapshot(_ snapshot: SimulatorUISnapshot) -> SimulatorUISnapshot {
        SimulatorUISnapshot(
            udid: snapshot.udid,
            bundleID: snapshot.bundleID,
            projectPath: "generated://apple-debug-mcp-xctest-ui-probe",
            scheme: "AppleDebugMCPUIProbe",
            debugDescription: snapshot.debugDescription,
            elements: snapshot.elements
        )
    }

    private static func runProbe(
        udid: String,
        bundleID: String,
        projectPath: String,
        scheme: String,
        configuration: String,
        action: SimulatorUIActionRequest?,
        extraBuildSettings: [String] = []
    ) throws -> SimulatorUISnapshot {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION"] == "1" else {
            throw SimulatorUIError.mutationDisabled
        }
        guard !bundleID.isEmpty, !scheme.isEmpty,
              bundleID.utf8.count <= 256, scheme.utf8.count <= 256 else {
            throw SimulatorUIError.invalidRequest
        }
        let projectURL = URL(fileURLWithPath: projectPath)
        guard FileManager.default.fileExists(atPath: projectURL.path),
              projectURL.pathExtension == "xcodeproj" || projectURL.pathExtension == "xcworkspace" else {
            throw SimulatorUIError.invalidProject
        }
        guard try SimulatorService.list().contains(where: { $0.udid == udid }) else {
            throw SimulatorUIError.unknownSimulator(udid)
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-ui-\(UUID().uuidString)", isDirectory: true)
        let derivedData = root.appendingPathComponent("DerivedData", isDirectory: true)
        let resultBundle = root.appendingPathComponent("UI.xcresult", isDirectory: true)
        let attachments = root.appendingPathComponent("attachments", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let projectFlag = projectURL.pathExtension == "xcodeproj" ? "-project" : "-workspace"
        var xcodebuildArguments = [
            projectFlag, projectURL.path,
            "-scheme", scheme,
            "-configuration", configuration,
            "-destination", "platform=iOS Simulator,id=\(udid)",
            "-derivedDataPath", derivedData.path,
            "-resultBundlePath", resultBundle.path,
            "CODE_SIGNING_ALLOWED=NO"
        ]
        xcodebuildArguments.append(contentsOf: extraBuildSettings)
        if let action {
            let actionData = try JSONEncoder().encode(action)
            xcodebuildArguments.append(
                "APPLE_DEBUG_UI_ACTION_BASE64=\(actionData.base64EncodedString())"
            )
        }
        xcodebuildArguments.append("test")
        let buildResult = try run(
            executable: "/usr/bin/xcodebuild",
            arguments: xcodebuildArguments
        )
        _ = buildResult

        try FileManager.default.createDirectory(at: attachments, withIntermediateDirectories: true)
        _ = try run(
            executable: "/usr/bin/xcrun",
            arguments: [
                "xcresulttool", "export", "attachments",
                "--path", resultBundle.path,
                "--output-path", attachments.path
            ]
        )
        let manifestURL = attachments.appendingPathComponent("manifest.json")
        guard let manifestData = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONSerialization.jsonObject(with: manifestData) as? [[String: Any]] else {
            throw SimulatorUIError.attachmentNotFound
        }

        for test in manifest {
            guard let records = test["attachments"] as? [[String: Any]] else { continue }
            for record in records {
                guard let exportedFileName = record["exportedFileName"] as? String,
                      let suggestedName = record["suggestedHumanReadableName"] as? String,
                      suggestedName.hasPrefix("apple-debug-mcp-ui-tree") else {
                    continue
                }
                let attachmentURL = attachments.appendingPathComponent(exportedFileName)
                guard let data = try? Data(contentsOf: attachmentURL), data.count <= maximumSnapshotSize else {
                    throw SimulatorUIError.outputTooLarge
                }
                do {
                    let payload = try JSONDecoder().decode(AccessibilityPayload.self, from: data)
                    return SimulatorUISnapshot(
                        udid: udid,
                        bundleID: bundleID,
                        projectPath: projectURL.path,
                        scheme: scheme,
                        debugDescription: payload.debugDescription,
                        elements: payload.elements
                    )
                } catch {
                    throw SimulatorUIError.invalidSnapshot
                }
            }
        }
        throw SimulatorUIError.attachmentNotFound
    }

    private static func validate(action: SimulatorUIActionRequest) throws {
        guard ["tap", "doubleTap", "longPress", "typeText", "swipe", "pinch", "wait", "coordinateTap", "coordinateLongPress", "coordinateSwipe"].contains(action.action) else {
            throw SimulatorUIError.invalidAction
        }
        if let identifier = action.identifier {
            guard !identifier.isEmpty, identifier.utf8.count <= 256, !identifier.contains("\0") else {
                throw SimulatorUIError.invalidAction
            }
        }
        switch action.action {
        case "tap", "doubleTap", "wait":
            guard action.identifier != nil else { throw SimulatorUIError.invalidAction }
        case "longPress":
            guard action.identifier != nil else { throw SimulatorUIError.invalidAction }
            let duration = action.durationSeconds ?? 1.0
            guard duration.isFinite, (0.1...10.0).contains(duration) else {
                throw SimulatorUIError.invalidAction
            }
        case "typeText":
            guard action.identifier != nil,
                  let text = action.text,
                  !text.contains("\0"),
                  text.utf8.count <= 4096 else {
                throw SimulatorUIError.invalidAction
            }
        case "swipe":
            guard ["up", "down", "left", "right"].contains(action.direction ?? "up") else {
                throw SimulatorUIError.invalidAction
            }
        case "pinch":
            guard action.identifier != nil, let scale = action.scale else {
                throw SimulatorUIError.invalidAction
            }
            let velocity = action.velocity ?? 1.0
            guard scale.isFinite, velocity.isFinite,
                  (0.5...2.0).contains(scale),
                  (-10.0...10.0).contains(velocity), velocity != 0 else {
                throw SimulatorUIError.invalidAction
            }
        case "coordinateTap":
            guard validCoordinate(action.x), validCoordinate(action.y) else { throw SimulatorUIError.invalidAction }
        case "coordinateLongPress":
            let duration = action.durationSeconds ?? 1.0
            guard validCoordinate(action.x), validCoordinate(action.y), duration.isFinite, (0.1...10.0).contains(duration) else {
                throw SimulatorUIError.invalidAction
            }
        case "coordinateSwipe":
            guard validCoordinate(action.x), validCoordinate(action.y), validCoordinate(action.endX), validCoordinate(action.endY) else {
                throw SimulatorUIError.invalidAction
            }
        default:
            throw SimulatorUIError.invalidAction
        }
    }

    private static func validCoordinate(_ value: Double?) -> Bool {
        guard let value else { return false }
        return value.isFinite && (0.0...1.0).contains(value)
    }

    private struct AccessibilityPayload: Codable {
        let bundleID: String
        let debugDescription: String
        let elements: [SimulatorUIElement]
        let action: String?
    }

    private static let generatedProject = #"""
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = { };
	objectVersion = 77;
	objects = {

/* Begin PBXBuildFile section */
		200000000000000000000001 /* AppleDebugMCPUIProbe.swift in Sources */ = {isa = PBXBuildFile; fileRef = 200000000000000000000002 /* AppleDebugMCPUIProbe.swift */; };
		200000000000000000000003 /* XCTest.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = 200000000000000000000004 /* XCTest.framework */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		200000000000000000000002 /* AppleDebugMCPUIProbe.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppleDebugMCPUIProbe.swift; sourceTree = "<group>"; };
		200000000000000000000005 /* AppleDebugMCPUIProbe.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = AppleDebugMCPUIProbe.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
		200000000000000000000004 /* XCTest.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = XCTest.framework; path = System/Library/Frameworks/XCTest.framework; sourceTree = SDKROOT; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		200000000000000000000006 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				200000000000000000000003 /* XCTest.framework in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		200000000000000000000007 = {
			isa = PBXGroup;
			children = (
				200000000000000000000002 /* AppleDebugMCPUIProbe.swift */,
				200000000000000000000008 /* Products */,
			);
			path = "";
			sourceTree = "<group>";
		};
		200000000000000000000008 /* Products */ = {
			isa = PBXGroup;
			children = (
				200000000000000000000005 /* AppleDebugMCPUIProbe.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		200000000000000000000009 /* AppleDebugMCPUIProbe */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 20000000000000000000000A /* Build configuration list for PBXNativeTarget "AppleDebugMCPUIProbe" */;
			buildPhases = (
				20000000000000000000000B /* Sources */,
				200000000000000000000006 /* Frameworks */,
			);
			buildRules = ();
			dependencies = ();
			name = AppleDebugMCPUIProbe;
			productName = AppleDebugMCPUIProbe;
			productReference = 200000000000000000000005 /* AppleDebugMCPUIProbe.xctest */;
			productType = "com.apple.product-type.bundle.ui-testing";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		20000000000000000000000C /* Project object */ = {
			isa = PBXProject;
			attributes = {
				LastUpgradeCheck = 2660;
			};
			buildConfigurationList = 20000000000000000000000D /* Build configuration list for PBXProject "AppleDebugMCPUIProbe" */;
			compatibilityVersion = "Xcode 3.2";
			developmentRegion = en;
			knownRegions = (en, Base);
			mainGroup = 200000000000000000000007;
			productRefGroup = 200000000000000000000008 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (200000000000000000000009 /* AppleDebugMCPUIProbe */);
		};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
		20000000000000000000000B /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (200000000000000000000001 /* AppleDebugMCPUIProbe.swift in Sources */);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		20000000000000000000000E /* Project Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				SDKROOT = iphonesimulator;
				SWIFT_VERSION = 5.0;
			};
			name = Debug;
		};
		20000000000000000000000F /* Project Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				SDKROOT = iphonesimulator;
				SWIFT_VERSION = 5.0;
			};
			name = Release;
		};
		200000000000000000000010 /* Target Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				APPLE_DEBUG_UI_ACTION_BASE64 = "";
				APPLE_DEBUG_UI_BUNDLE_ID = "";
				CODE_SIGNING_ALLOWED = NO;
				CODE_SIGNING_REQUIRED = NO;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_APPLE_DEBUG_UI_ACTION_BASE64 = "$(APPLE_DEBUG_UI_ACTION_BASE64)";
				INFOPLIST_KEY_APPLE_DEBUG_UI_BUNDLE_ID = "$(APPLE_DEBUG_UI_BUNDLE_ID)";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.burakkarahan.AppleDebugMCPUIProbe;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphonesimulator;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
			};
			name = Debug;
		};
		200000000000000000000011 /* Target Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				APPLE_DEBUG_UI_ACTION_BASE64 = "";
				APPLE_DEBUG_UI_BUNDLE_ID = "";
				CODE_SIGNING_ALLOWED = NO;
				CODE_SIGNING_REQUIRED = NO;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_APPLE_DEBUG_UI_ACTION_BASE64 = "$(APPLE_DEBUG_UI_ACTION_BASE64)";
				INFOPLIST_KEY_APPLE_DEBUG_UI_BUNDLE_ID = "$(APPLE_DEBUG_UI_BUNDLE_ID)";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.burakkarahan.AppleDebugMCPUIProbe;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphonesimulator;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		20000000000000000000000D /* Build configuration list for PBXProject "AppleDebugMCPUIProbe" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				20000000000000000000000E /* Project Debug */,
				20000000000000000000000F /* Project Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		20000000000000000000000A /* Build configuration list for PBXNativeTarget "AppleDebugMCPUIProbe" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				200000000000000000000010 /* Target Debug */,
				200000000000000000000011 /* Target Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = 20000000000000000000000C /* Project object */;
}
"""#

    private static let generatedSource = #"""
import Foundation
import XCTest

final class AppleDebugMCPUIProbeTests: XCTestCase {
    func testCaptureAccessibilityTree() throws {
        let bundleID = "__APPLE_DEBUG_UI_BUNDLE_ID__"
        guard !bundleID.isEmpty else {
            throw NSError(domain: "AppleDebugMCP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing target bundle identifier"])
        }
        let app = XCUIApplication(bundleIdentifier: bundleID)
        app.launch()
        guard app.wait(for: .runningForeground, timeout: 10) else {
            throw NSError(domain: "AppleDebugMCP", code: 2, userInfo: [NSLocalizedDescriptionKey: "Target application did not reach the foreground"])
        }

        let action = try actionCommand()
        if let action {
            try perform(action: action, in: app)
        }

        let elements = app.descendants(matching: .any).allElementsBoundByIndex.map { element in
            ElementRecord(
                type: element.elementType.rawValue,
                identifier: element.identifier,
                label: element.label,
                value: element.value.map { String(describing: $0) },
                exists: element.exists,
                hittable: element.isHittable,
                frame: [
                    "x": element.frame.origin.x,
                    "y": element.frame.origin.y,
                    "width": element.frame.size.width,
                    "height": element.frame.size.height
                ]
            )
        }
        let payload = SnapshotPayload(
            bundleID: bundleID,
            debugDescription: app.debugDescription,
            elements: elements,
            action: action?.action
        )
        let attachment = XCTAttachment(data: try JSONEncoder().encode(payload), uniformTypeIdentifier: "public.json")
        attachment.name = "apple-debug-mcp-ui-tree.json"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
    }

    private func actionCommand() throws -> UIActionCommand? {
        let encoded = "__APPLE_DEBUG_UI_ACTION_BASE64__"
        guard !encoded.isEmpty else { return nil }
        guard let data = Data(base64Encoded: encoded) else {
            throw NSError(domain: "AppleDebugMCP", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid UI action encoding"])
        }
        return try JSONDecoder().decode(UIActionCommand.self, from: data)
    }

    private func perform(action: UIActionCommand, in app: XCUIApplication) throws {
        let element: XCUIElement?
        if let identifier = action.identifier {
            let candidate = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            guard candidate.waitForExistence(timeout: 10) else {
                throw NSError(domain: "AppleDebugMCP", code: 4, userInfo: [NSLocalizedDescriptionKey: "UI element was not found: \(identifier)"])
            }
            element = candidate
        } else {
            element = nil
        }
        switch action.action {
        case "tap":
            guard let element else { throw invalidAction("tap requires identifier") }
            element.tap()
        case "doubleTap":
            guard let element else { throw invalidAction("doubleTap requires identifier") }
            element.doubleTap()
        case "longPress":
            guard let element else { throw invalidAction("longPress requires identifier") }
            element.press(forDuration: action.durationSeconds ?? 1.0)
        case "typeText":
            guard let element, let text = action.text else { throw invalidAction("typeText requires identifier and text") }
            element.tap()
            element.typeText(text)
        case "swipe":
            switch action.direction ?? "up" {
            case "up": element?.swipeUp() ?? app.swipeUp()
            case "down": element?.swipeDown() ?? app.swipeDown()
            case "left": element?.swipeLeft() ?? app.swipeLeft()
            case "right": element?.swipeRight() ?? app.swipeRight()
            default: throw invalidAction("invalid swipe direction")
            }
        case "pinch":
            guard let element, let scale = action.scale else { throw invalidAction("pinch requires identifier and scale") }
            element.pinch(withScale: CGFloat(scale), velocity: CGFloat(action.velocity ?? 1.0))
        case "wait":
            guard element?.waitForExistence(timeout: 10) == true else { throw invalidAction("wait requires identifier") }
        case "coordinateTap":
            guard let x = action.x, let y = action.y else { throw invalidAction("coordinateTap requires x and y") }
            app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
        case "coordinateLongPress":
            guard let x = action.x, let y = action.y else { throw invalidAction("coordinateLongPress requires x and y") }
            app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).press(forDuration: action.durationSeconds ?? 1.0)
        case "coordinateSwipe":
            guard let x = action.x, let y = action.y, let endX = action.endX, let endY = action.endY else {
                throw invalidAction("coordinateSwipe requires x, y, endX, and endY")
            }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: endX, dy: endY))
            start.press(forDuration: 0.1, thenDragTo: end)
        default:
            throw invalidAction("unsupported UI action")
        }
    }

    private func invalidAction(_ message: String) -> NSError {
        NSError(domain: "AppleDebugMCP", code: 5, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

private struct SnapshotPayload: Codable {
    let bundleID: String
    let debugDescription: String
    let elements: [ElementRecord]
    let action: String?
}

private struct UIActionCommand: Codable {
    let action: String
    let identifier: String?
    let text: String?
    let direction: String?
    let durationSeconds: Double?
    let scale: Double?
    let velocity: Double?
    let x: Double?
    let y: Double?
    let endX: Double?
    let endY: Double?
}

private struct ElementRecord: Codable {
    let type: UInt
    let identifier: String
    let label: String
    let value: String?
    let exists: Bool
    let hittable: Bool
    let frame: [String: CGFloat]
}
"""#

    private struct CommandResult {
        let stdout: String
        let stderr: String
    }

    private static func run(executable: String, arguments: [String]) throws -> CommandResult {
        let result: AppleProcessResult
        do {
            result = try AppleProcessRunner.run(
                executable: executable,
                arguments: arguments,
                maximumOutputSize: maximumCommandOutput,
                timeoutMilliseconds: 600_000
            )
        } catch AppleProcessRunnerError.outputTooLarge {
            throw SimulatorUIError.outputTooLarge
        } catch {
            throw SimulatorUIError.commandFailed(error.localizedDescription)
        }
        let stdout = String(decoding: result.stdout, as: UTF8.self)
        let stderr = String(decoding: result.stderr, as: UTF8.self)
        guard result.terminationStatus == 0 else {
            let diagnostics = [stderr, stdout]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            throw SimulatorUIError.commandFailed(diagnostics.isEmpty ? "Apple UI test command failed." : diagnostics)
        }
        return CommandResult(stdout: stdout, stderr: stderr)
    }
}
