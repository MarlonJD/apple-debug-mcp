// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Darwin
import Foundation

enum AppleBoundedFileError: Error, Equatable {
    case invalidLimit
    case notRegular
    case tooLarge
}

enum AppleBoundedFile {
    static func readData(atPath path: String, maximumSize: Int) throws -> Data {
        guard maximumSize > 0 else {
            throw AppleBoundedFileError.invalidLimit
        }

        var fileStatus = stat()
        guard lstat(path, &fileStatus) == 0 else {
            throw AppleBoundedFileError.notRegular
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            throw AppleBoundedFileError.notRegular
        }
        guard fileStatus.st_size >= 0,
              fileStatus.st_size <= Int64(maximumSize) else {
            throw AppleBoundedFileError.tooLarge
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard data.count <= maximumSize else {
            throw AppleBoundedFileError.tooLarge
        }
        return data
    }
}
