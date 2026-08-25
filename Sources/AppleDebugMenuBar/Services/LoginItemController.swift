// Apple Debug MCP Menu Bar
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import ServiceManagement

@MainActor
final class LoginItemController {
    var onStatusChange: ((Bool) -> Void)?

    var status: SMAppService.Status { SMAppService.mainApp.status }
    var isEnabled: Bool { status == .enabled }

    var statusDescription: String {
        switch status {
        case .enabled: return "Enabled"
        case .requiresApproval: return "Approval required in System Settings"
        case .notRegistered: return "Disabled"
        case .notFound: return "Install the signed app in /Applications to enable login"
        @unknown default: return "Unknown"
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        onStatusChange?(isEnabled)
    }
}
