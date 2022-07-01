//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
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
            let entry = findEntry(at: link.href),
            let reader = archive.readEntry(at: entry.path)
        else {
            return FailureResource(link: link, error: .notFound(nil))
        }

        return ArchiveResource(link: link, entry: entry, reader: reader)
    }
    
    private func findEntry(at href: String) -> ArchiveEntry? {
        if let entry = archive.entry(at: href) {
            return entry
        }
        
        // Try after removing query parameters and anchors from the href.
        guard let href = href.components(separatedBy: .init(charactersIn: "#?")).first else {
            return nil
        }
        
        return archive.entry(at: href)
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
