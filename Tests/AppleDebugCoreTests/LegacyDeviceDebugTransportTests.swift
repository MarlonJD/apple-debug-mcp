// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class LegacyDeviceDebugTransportTests: XCTestCase {
    func testParsesIosDeployDebugserverMetadataFromMixedOutput() throws {
        let output = """
        [100%] Listening for lldb connections
        debugserver port: 60364
        App path: /private/var/containers/Bundle/Application/ABC/DebugApp.app
        """

        let metadata = try XCTUnwrap(
            LegacyDeviceDebugTransport.parseDebugServerOutput(output)
        )

        XCTAssertEqual(
            metadata,
            LegacyDeviceDebugServerMetadata(
                port: 60364,
                remoteAppPath: "/private/var/containers/Bundle/Application/ABC/DebugApp.app"
            )
        )
    }

    func testRequiresBothPortAndRemoteAppPath() {
        XCTAssertNil(
            LegacyDeviceDebugTransport.parseDebugServerOutput(
                "debugserver port: 60364"
            )
        )
        XCTAssertNil(
            LegacyDeviceDebugTransport.parseDebugServerOutput(
                "App path: /private/app/DebugApp.app"
            )
        )
    }
}
