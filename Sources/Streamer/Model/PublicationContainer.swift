//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Temporary solution to migrate `Publication.get()` while ensuring backward compatibility with
/// `Container`.
@available(*, unavailable, message: "Use `Publication.get()` to access a publication's resources")
final class PublicationContainer: Container {
    var rootFile: RootFile
    var drm: DRM?

    private let publication: Publication

    init(publication: Publication, path: String, mimetype: String, drm: DRM? = nil) {
        self.publication = publication
        rootFile = RootFile(rootPath: path, mimetype: mimetype)
        self.drm = drm
    }

    func data(relativePath: String) throws -> Data {
        try publication.get(relativePath).read().get()
    }

    func dataLength(relativePath: String) throws -> UInt64 {
        try publication.get(relativePath).length.get()
    }

    func dataInputStream(relativePath: String) throws -> SeekableInputStream {
        try publication.get(relativePath).stream().get()
    }
}
