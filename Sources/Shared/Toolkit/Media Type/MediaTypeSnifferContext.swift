//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

// FIXME: ZIP and XML capabilities are internal for now, until the API of `Archive` and `XMLDocument` are stable.

/// A companion type of `MediaType.Sniffer` holding the type hints (file extensions, media types) and
/// providing an access to the file content.
public final class MediaTypeSnifferContext {
    private let archiveFactory: ArchiveFactory
    private let xmlFactory: XMLDocumentFactory

    internal init(content: MediaTypeSnifferContent? = nil, mediaTypes: [String], fileExtensions: [String], archiveFactory: ArchiveFactory = DefaultArchiveFactory(), xmlFactory: XMLDocumentFactory = DefaultXMLDocumentFactory()) {
        self.content = content
        self.mediaTypes = mediaTypes.compactMap { MediaType($0) }
        self.fileExtensions = fileExtensions.map { $0.lowercased() }
        self.archiveFactory = archiveFactory
        self.xmlFactory = xmlFactory
    }

    // MARK: Metadata

    /// Media type hints.
    let mediaTypes: [MediaType]

    /// File extension hints.
    let fileExtensions: [String]

    /// Finds the first `Encoding` declared in the media types' `charset` parameter.
    public lazy var encoding: String.Encoding? =
        mediaTypes.compactMap(\.encoding).first

    /// Returns whether this context has any of the given file extensions, ignoring case.
    public func hasFileExtension(_ fileExtensions: String...) -> Bool {
        for fileExtension in fileExtensions {
            if self.fileExtensions.contains(fileExtension.lowercased()) {
                return true
            }
        }
        return false
    }

    /// Returns whether this context has any of the given media type, ignoring case and extra
    /// parameters.
    ///
    /// Implementation note: Use `MediaType` to handle the comparison to avoid edge cases.
    public func hasMediaType(_ mediaTypes: String...) -> Bool {
        let mediaTypes = mediaTypes.compactMap { MediaType($0) }
        for mediaType in mediaTypes {
            if self.mediaTypes.contains(where: { mediaType.contains($0) }) {
                return true
            }
        }
        return false
    }

    // MARK: Content

    /// Underlying content holder.
    private let content: MediaTypeSnifferContent?

    /// Content as plain text.
    ///
    /// It will extract the charset parameter from the media type hints to figure out an encoding.
    /// Otherwise, fallback on UTF-8.
    public lazy var contentAsString: String? = content?.read()
        .flatMap { String(data: $0, encoding: encoding ?? .utf8) }

    /// Content as an XML document.
    lazy var contentAsXML: XMLDocument? = contentAsString
        .flatMap { try? xmlFactory.open(string: $0, namespaces: []) }

    /// Content as an archive.
    /// Warning: ZIP is only supported for a local file, for now.
    lazy var contentAsArchive: Archive? = (content as? FileMediaTypeSnifferContent)
        .flatMap { archiveFactory.open(url: $0.file, password: nil).getOrNil() }

    /// Content parsed from JSON.
    public lazy var contentAsJSON: Any? = contentAsString
        .flatMap { $0.data(using: .utf8) }
        .flatMap { try? JSONSerialization.jsonObject(with: $0) }

    /// Publication parsed from the content.
    public lazy var contentAsRWPM: Manifest? = contentAsJSON
        .flatMap { try? Manifest(json: $0) }

    /// Raw bytes stream of the content.
    ///
    /// A byte stream can be useful when sniffers only need to read a few bytes at the beginning of
    /// the file.
    public func stream() -> InputStream? {
        content?.stream()
    }

    /// Reads the first `length` bytes.
    ///
    /// It can be used to check a file signature, aka magic number.
    /// See https://en.wikipedia.org/wiki/List_of_file_signatures
    func read(length: Int) -> Data? {
        guard let stream = stream() else {
            return nil
        }

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        stream.open()
        defer {
            stream.close()
            buffer.deallocate()
        }

        let bytesRead = stream.read(buffer, maxLength: length)
        guard bytesRead > 0 else {
            return nil
        }

        return Data(bytes: buffer, count: bytesRead)
    }

    /// Returns whether an Archive entry exists in this file.
    func containsArchiveEntry(at path: String) -> Bool {
        contentAsArchive?.entry(at: path) != nil
    }

    /// Returns the Archive entry data at the given `path` in this file.
    func readArchiveEntry(at path: String) -> Data? {
        contentAsArchive?.readEntry(at: path)?.read().getOrNil()
    }

    /// Returns whether the Archive entry paths satisfy at least one of the
    /// `requiredExtensions`. The other extensions must satisfy the
    /// `allowedExtensions`.
    func archiveEntriesContains(requiredExtensions: [String], allowedExtensions: [String]) -> Bool {
        guard let entries = contentAsArchive?.entries else {
            return false
        }

        func isIgnored(_ url: URL) -> Bool {
            let filename = url.lastPathComponent
            return url.hasDirectoryPath || filename.hasPrefix(".") || filename == "Thumbs.db"
        }

        var containsRequiredExtensions = false
        for entry in entries {
            let url = URL(fileURLWithPath: entry.path)
            guard !isIgnored(url) else {
                continue
            }

            let ext = url.pathExtension.lowercased()

            if requiredExtensions.contains(ext) {
                containsRequiredExtensions = true
            } else if !allowedExtensions.contains(ext) {
                return false
            }
        }

        return containsRequiredExtensions
    }
}
