//
//  PublicationContainer.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 31/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
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
        self.rootFile = RootFile(rootPath: path, mimetype: mimetype)
        self.drm = drm
    }

    func data(relativePath: String) throws -> Data {
        return try publication.get(relativePath).read().get()
    }
    
    func dataLength(relativePath: String) throws -> UInt64 {
        return try publication.get(relativePath).length.get()
    }
    
    func dataInputStream(relativePath: String) throws -> SeekableInputStream {
        return try publication.get(relativePath).stream().get()
    }
}
