//
//  FormatSnifferContext.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 10/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

// FIXME: ZIP and XML capabilities are internal for now, until the API of `Archive` and `XMLDocument` are stable.

/// A companion type of `Format.Sniffer` holding the type hints (file extensions, media types) and
/// providing an access to the file content.
public final class FormatSnifferContext {
    
    internal init(content: FormatSnifferContent? = nil, mediaTypes: [String], fileExtensions: [String]) {
        self.content = content
        self.mediaTypes = mediaTypes.compactMap { MediaType($0) }
        self.fileExtensions = fileExtensions.map { $0.lowercased() }
    }
    
    // MARK: Metadata

    /// Media type hints.
    let mediaTypes: [MediaType]
    
    /// File extension hints.
    let fileExtensions: [String]

    /// Finds the first `Encoding` declared in the media types' `charset` parameter.
    public lazy var encoding: String.Encoding? =
        mediaTypes.compactMap { $0.encoding }.first

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
    private let content: FormatSnifferContent?
    
    /// Content as plain text.
    ///
    /// It will extract the charset parameter from the media type hints to figure out an encoding.
    /// Otherwise, fallback on UTF-8.
    public lazy var contentAsString: String? = content?.read()
        .flatMap { String(data: $0, encoding: encoding ?? .utf8) }

    /// Content as an XML document.
    lazy var contentAsXML: XMLDocument? = contentAsString
        .flatMap { FuziXMLDocument(string: $0) }

    /// Content as a ZIP archive.
    /// Warning: ZIP is only supported for a local file, for now.
    lazy var contentAsZIP: Archive? = (content as? FormatSnifferFileContent)
        .flatMap { try? MinizipArchive(file: $0.file) }

    /// Content parsed from JSON.
    public lazy var contentAsJSON: Any? = contentAsString
        .flatMap { $0.data(using: .utf8) }
        .flatMap { try? JSONSerialization.jsonObject(with: $0) }
    
    /// Publication parsed from the content.
    public lazy var contentAsRWPM: Publication? = contentAsJSON
        .flatMap { try? Publication(json: $0) }

    /// Raw bytes stream of the content.
    ///
    /// A byte stream can be useful when sniffers only need to read a few bytes at the beginning of
    /// the file.
    public func stream() -> InputStream? {
        return content?.stream()
    }

    /// Reads the file signature, aka magic number, at the beginning of the content, up to `length`
    /// bytes.
    /// i.e. https://en.wikipedia.org/wiki/List_of_file_signatures
    public func readFileSignature(length: Int) -> String? {
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
        return bytesRead > 0 ? String(cString: buffer) : nil
    }
    
    /// Returns whether a ZIP entry exists in this file.
    func containsZIPEntry(at path: String) -> Bool {
        return contentAsZIP?.entry(at: path) != nil
    }
    
    /// Returns the ZIP entry data at the given `path` in this file.
    func readZIPEntry(at path: String) -> Data? {
        return contentAsZIP?.read(at: path)
    }
    
    /// Returns whether all the ZIP entry paths satisfy the given `predicate`.
    func zipEntriesAllSatisfy(_ predicate: (URL) -> Bool) -> Bool {
        return contentAsZIP?.entries
            .map { URL(fileURLWithPath: $0.path, isDirectory: $0.isDirectory) }
            .allSatisfy(predicate)
            ?? false
    }

}
