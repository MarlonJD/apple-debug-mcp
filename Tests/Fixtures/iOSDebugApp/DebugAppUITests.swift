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
            elements: elements
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
}

private struct SnapshotPayload: Codable {
    let bundleID: String
    let debugDescription: String
    let elements: [ElementRecord]
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
