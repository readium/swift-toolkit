//
//  ArchiveFetcher.swift
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
public final class ArchiveFetcher: Fetcher, Loggable {
    
    private let archive: Archive
    
    public init(archive: Archive) {
        self.archive = archive
    }
    
    public lazy var links: [Link] =
        archive.entries.map { entry in
            Link(
                href: entry.path.addingPrefix("/"),
                type: Format.of(fileExtension: URL(fileURLWithPath: entry.path).pathExtension)?.mediaType.string,
                properties: .init([
                    "compressedLength": entry.compressedLength as Any
                ])
            )
        }

    public func get(_ link: Link) -> Resource {
        return ArchiveResource(link: link, archive: archive)
    }
    
    public func close() {}
    
    private final class ArchiveResource: Resource {
        
        lazy var link: Link = {
            var link = originalLink
            if let compressedLength = entry?.compressedLength {
                link = link.addingProperties(["compressedLength": Int(compressedLength)])
            }
            return link
        }()
        
        private let originalLink: Link
        private let href: String
        
        private let archive: Archive
        private lazy var entry: ArchiveEntry? = try? archive.entry(at: href)

        init(link: Link, archive: Archive) {
            self.originalLink = link
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
