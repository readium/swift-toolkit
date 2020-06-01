//
//  ArchiveFetcher.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 01/06/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

extension ArchiveFetcher {
    
    /// Creates an `ArchiveFetcher` from either an archive file, or an exploded directory.
    static func make(archiveOrDirectory url: URL) -> Fetcher? {
        let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false
        if isDirectory ?? false {
            return FileFetcher(href: "/", path: url)
        } else {
            return ArchiveFetcher(archive: url)
        }
    }
    
}
