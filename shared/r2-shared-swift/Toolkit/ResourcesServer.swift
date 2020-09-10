//
//  ResourcesServer.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 21.06.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

public enum ResourcesServerError: Error {
    case fileNotFound
    case invalidPath
    case serverFailure
}

public protocol ResourcesServer {
    
    /// Serves the local file URL at the given absolute path on the server.
    /// If the given URL is a directory, then all the files in the directory are served.
    /// Subsequent calls with the same served path overwrite each other.
    ///
    /// Returns: The URL to access the file on the server.
    @discardableResult
    func serve(_ url: URL, at path: String) throws -> URL
    
}
