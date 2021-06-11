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
                type: MediaType.of(fileExtension: URL(fileURLWithPath: entry.path).pathExtension)?.string,
                properties: Properties(entry.linkProperties)
            )
        }

    public func get(_ link: Link) -> Resource {
        guard
            let entry = archive.entry(at: link.href),
            let reader = archive.readEntry(at: link.href)
        else {
            return FailureResource(link: link, error: .notFound(nil))
        }

        return ArchiveResource(link: link, entry: entry, reader: reader)
    }
    
    public func close() {}
    
    private final class ArchiveResource: Resource {
        
        lazy var link: Link = {
            originalLink.addingProperties(entry.linkProperties)
        }()
        
        var file: URL? { reader.file }
        
        private let originalLink: Link

        private let entry: ArchiveEntry
        private let reader: ArchiveEntryReader

        init(link: Link, entry: ArchiveEntry, reader: ArchiveEntryReader) {
            self.originalLink = link
            self.entry = entry
            self.reader = reader
        }

        var length: Result<UInt64, ResourceError> { .success(entry.length) }

        func read(range: Range<UInt64>?) -> Result<Data, ResourceError> {
            reader.read(range: range)
                .mapError { ResourceError.unavailable($0) }
        }
        
        func close() {
            reader.close()
        }

    }

}

private extension ArchiveEntry {

    var linkProperties: [String: Any] {
        [
            // FIXME: Legacy property, should be removed in 3.0.0
            "compressedLength": compressedLength as Any,

            "archive": [
                "entryLength": compressedLength ?? length,
                "isEntryCompressed": compressedLength != nil
            ]
        ]
    }

}
