// Apple Debug MCP iOS UI fixture
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import XCTest

final class DebugAppUITests: XCTestCase {
    func testCaptureAccessibilityTree() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--apple-debug-mcp-ui-tree"]
        app.launch()

        XCTAssertTrue(
            app.staticTexts["debug.fixture.title"].waitForExistence(timeout: 10),
            "The fixture title was not exposed through XCTest accessibility"
        )
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
            bundleID: "com.burakkarahan.AppleDebugFixture",
            debugDescription: app.debugDescription,
            elements: elements,
            action: action?.action
        )
        let data = try JSONEncoder().encode(payload)
        let attachment = XCTAttachment(
            data: data,
            uniformTypeIdentifier: "public.json"
        )
        attachment.name = "apple-debug-mcp-ui-tree.json"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
    }

    private func actionCommand() throws -> UIActionCommand? {
        guard let encoded = Bundle(for: Self.self)
            .object(forInfoDictionaryKey: "APPLE_DEBUG_UI_ACTION_BASE64") as? String,
              !encoded.isEmpty else {
            return nil
        }
        guard let data = Data(base64Encoded: encoded) else {
            throw NSError(
                domain: "AppleDebugMCP",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "UI action configuration is not valid base64"]
            )
        }
        do {
            return try JSONDecoder().decode(UIActionCommand.self, from: data)
        } catch {
            throw NSError(
                domain: "AppleDebugMCP",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "UI action configuration is not valid JSON"]
            )
        }
    }

    private func perform(action: UIActionCommand, in app: XCUIApplication) throws {
        let element: XCUIElement?
        if let identifier = action.identifier {
            let candidate = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            guard candidate.waitForExistence(timeout: 10) else {
                throw NSError(
                    domain: "AppleDebugMCP",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "UI element was not found: (identifier)"]
                )
            }
            element = candidate
        } else {
            element = nil
        }

        switch action.action {
        case "tap":
            guard let element else { throw invalidAction("tap requires identifier") }
            element.tap()
        case "typeText":
            guard let element, let text = action.text else {
                throw invalidAction("typeText requires identifier and text")
            }
            element.tap()
            element.typeText(text)
        case "swipe":
            switch action.direction ?? "up" {
            case "up": element?.swipeUp() ?? app.swipeUp()
            case "down": element?.swipeDown() ?? app.swipeDown()
            case "left": element?.swipeLeft() ?? app.swipeLeft()
            case "right": element?.swipeRight() ?? app.swipeRight()
            default: throw invalidAction("swipe direction must be up, down, left, or right")
            }
        case "wait":
            guard element?.waitForExistence(timeout: 10) == true else {
                throw invalidAction("wait requires an existing identifier")
            }
        default:
            throw invalidAction("unsupported UI action: (action.action)")
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
