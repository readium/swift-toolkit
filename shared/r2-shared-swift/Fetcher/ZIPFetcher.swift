//
//  ZIPFetcher.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 11/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/** Provides access to entries of a ZIP archive. */
final class ZIPFetcher: Fetcher, Loggable {
    
    private let archive: Archive
    
    init?(archive: URL) {
        do {
            self.archive = try MinizipArchive(file: archive)
        } catch {
            Self.log(.error, error)
            return nil
        }
    }
    
    func get(_ link: Link, parameters: LinkParameters) -> Resource {
        return ZIPResource(link: link, archive: archive)
    }
    
    func close() {}
    
    private final class ZIPResource: Resource {
        
        let link: Link
        private let href: String
        
        private let archive: Archive
        private lazy var entry: ArchiveEntry? = archive.entry(at: href)

        init(link: Link, archive: Archive) {
            self.link = link
            self.href = link.href.removingPrefix("/")
            self.archive = archive
        }

        var length: Result<UInt64, ResourceError> {
            guard let length = entry?.length else {
                return .failure(.notFound)
            }
            return .success(length)
        }
        
        func read(range: Range<UInt64>?) -> Result<Data, ResourceError> {
            guard entry != nil else {
                return .failure(.notFound)
            }
            let data: Data? = {
                if let range = range {
                    return archive.read(at: href, range: range)
                } else {
                    return archive.read(at: href)
                }
            }()
            
            if let data = data {
                return .success(data)
            } else {
                return .failure(.unavailable)
            }
        }
        
        func close() {}

    }
    
}
