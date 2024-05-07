//
//  Copyright 2024 Readium Foundation. All rights reserved.
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
        archive.entries.compactMap { entry in
            guard let url = RelativeURL(path: entry.path) else {
                return nil
            }
            return Link(
                href: url.string,
                type: MediaType.of(fileExtension: url.pathExtension)?.string,
                properties: Properties(entry.linkProperties)
            )
        }

    public func get(_ link: Link) -> Resource {
        guard
            let path = try? link.url().relativeURL?.path,
            let entry = findEntry(at: path),
            let reader = archive.readEntry(at: entry.path)
        else {
            log(.warning, "Unable to create ArchiveResource from link \(link)")
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
            var link = originalLink
            link.addProperties(entry.linkProperties)
            return link
        }()

        var file: FileURL? { reader.file }

        private let originalLink: Link

        private let entry: ArchiveEntry
        private let reader: ArchiveEntryReader

        init(link: Link, entry: ArchiveEntry, reader: ArchiveEntryReader) {
            originalLink = link
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
                "isEntryCompressed": compressedLength != nil,
            ] as [String: Any],
        ]
    }
}
