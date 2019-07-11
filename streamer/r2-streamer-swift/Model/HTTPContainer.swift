//
//  HTTPContainer.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 25.06.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared


/// Container to access remote files through HTTP requests.
class HTTPContainer: Container, Loggable {
    
    var rootFile: RootFile
    var drm: DRM?

    let baseURL: URL

    init(baseURL: URL, mimetype: String) {
        self.baseURL = baseURL
        self.rootFile = RootFile(rootPath: baseURL.absoluteString, mimetype: mimetype)
    }
    
    func data(relativePath: String) throws -> Data {
        return try Data(contentsOf: baseURL.appendingPathComponent(relativePath))
    }
    
    func dataLength(relativePath: String) throws -> UInt64 {
        return UInt64(try data(relativePath: relativePath).count)
    }
    
    func dataInputStream(relativePath: String) throws -> SeekableInputStream {
        return DataInputStream(data: try data(relativePath: relativePath))
    }

}
