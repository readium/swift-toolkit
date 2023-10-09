//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Container to access remote files through HTTP requests.
@available(*, unavailable, message: "Use `Publication.get()` to access a publication's resources")
class HTTPContainer: Container, Loggable {
    var rootFile: RootFile
    var drm: DRM?

    let baseURL: URL

    init(baseURL: URL, mimetype: String) {
        self.baseURL = baseURL
        rootFile = RootFile(rootPath: baseURL.absoluteString, mimetype: mimetype)
    }

    func data(relativePath: String) throws -> Data {
        try Data(contentsOf: baseURL.appendingPathComponent(relativePath))
    }

    func dataLength(relativePath: String) throws -> UInt64 {
        try UInt64(data(relativePath: relativePath).count)
    }

    func dataInputStream(relativePath: String) throws -> SeekableInputStream {
        try DataInputStream(data: data(relativePath: relativePath))
    }
}
