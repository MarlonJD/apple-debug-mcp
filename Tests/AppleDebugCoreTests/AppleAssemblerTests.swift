// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import AppleDebugCore

final class AppleAssemblerTests: XCTestCase {
    func testAssemblesArm64AndReturnsDisassembly() throws {
        let result = try AppleAssemblerService.assemble(
            source: "mov x0, x0\nret\n",
            architecture: "arm64"
        )

        XCTAssertEqual(result.bytesHex, "e00300aac0035fd6")
        XCTAssertEqual(result.byteCount, 8)
        XCTAssertTrue(result.disassembly.contains("mov\tx0, x0"))
        XCTAssertTrue(result.disassembly.contains("ret"))
    }

    func testRejectsFileIncludingAssembly() {
        XCTAssertThrowsError(
            try AppleAssemblerService.assemble(
                source: ".include \"/tmp/secret.s\"",
                architecture: "arm64"
            )
        ) { error in
            XCTAssertEqual(error as? AppleAssemblerError, .invalidRequest)
        }
    }
}
