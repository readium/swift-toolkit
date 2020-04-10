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

/// A companion type of `Format.Sniffer` holding the type hints (file extensions, media types) and
/// providing an access to the file content.
public protocol FormatSnifferContext {

    /// Content as plain text.
    ///
    /// It will extract the charset parameter from the media type hints to figure out an encoding.
    /// Otherwise, fallback on UTF-8.
    var contentAsString: String? { get }
    
    /// Content parsed from JSON.
    var contentAsJSON: Any? { get }
    
    /// Returns whether this context has any of the given file extensions, ignoring case.
    func hasFileExtension(_ fileExtensions: String...) -> Bool
    
    /// Returns whether this context has any of the given media type, ignoring case and extra
    /// parameters.
    ///
    /// Implementation note: Use `MediaType` to handle the comparison to avoid edge cases.
    func hasMediaType(_ mediaTypes: String...) -> Bool
    
    /// Raw bytes stream of the content.
    ///
    /// A byte stream can be useful when sniffers only need to read a few bytes at the beginning of
    /// the file.
    func stream() -> InputStream?
    
    /// Closes any opened file handles.
    func close()

}

public extension FormatSnifferContext {

    /// Publication parsed from the content.
    var contentAsRWPM: Publication? {
        contentAsJSON.flatMap { try? Publication(json: $0) }
    }
    
    /// Reads the file signature, aka magic number, at the beginning of the content, up to `length`
    /// bytes.
    /// i.e. https://en.wikipedia.org/wiki/List_of_file_signatures
    func readFileSignature(length: Int) -> String? {
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

}

class FormatBaseSnifferContext: FormatSnifferContext {

    /// Media type hints.
    let mediaTypes: [MediaType]
    
    /// File extension hints.
    let fileExtensions: [String]
    
    init(mediaTypes: [String] = [], fileExtensions: [String] = []) {
        self.mediaTypes = mediaTypes.compactMap { MediaType($0) }
        self.fileExtensions = fileExtensions.map { $0.lowercased() }
    }
    
    lazy var contentAsString: String? = readAsString()
    
    lazy var contentAsJSON: Any? = contentAsString
        .flatMap { $0.data(using: .utf8) }
        .flatMap { try? JSONSerialization.jsonObject(with: $0) }
    
    /// Finds the first `Encoding` declared in the media types' `charset` parameter.
    lazy var encoding: String.Encoding? =
        mediaTypes.compactMap { $0.encoding }.first

    /// To override in subclasses.
    func readAsString() -> String? {
        return nil
    }

    func hasFileExtension(_ fileExtensions: String...) -> Bool {
        for fileExtension in fileExtensions {
            if self.fileExtensions.contains(fileExtension.lowercased()) {
                return true
            }
        }
        return false
    }
    
    func hasMediaType(_ mediaTypes: String...) -> Bool {
        let mediaTypes = mediaTypes.compactMap { MediaType($0) }
        for mediaType in mediaTypes {
            if self.mediaTypes.contains(where: { mediaType.contains($0) }) {
                return true
            }
        }
        return false
    }
    
    func stream() -> InputStream? {
        return nil
    }
    
    func close() {}

}

/// Used to sniff only the media type and file extension hints.
class FormatMetadataSnifferContext: FormatBaseSnifferContext {}

/// Used to sniff a local file.
class FormatFileSnifferContext: FormatBaseSnifferContext {
    
    let file: URL
    
    init(file: URL, mediaTypes: [String], fileExtensions: [String]) {
        assert(file.isFileURL)
        self.file = file
        super.init(mediaTypes: mediaTypes, fileExtensions: [file.pathExtension] + fileExtensions)
    }
    
    override func readAsString() -> String? {
        return try? String(contentsOf: file, encoding: encoding ?? .utf8)
    }
    
    override func stream() -> InputStream? {
        return InputStream(url: file)
    }
    
}

/// Used to sniff a bytes array.
class FormatDataSnifferContext: FormatBaseSnifferContext {
    
    lazy var data: Data = getData()

    private let getData: () -> Data
    
    init(data: @escaping () -> Data, mediaTypes: [String], fileExtensions: [String]) {
        self.getData = data
        super.init(mediaTypes: mediaTypes, fileExtensions: fileExtensions)
    }

    override func readAsString() -> String? {
        return String(data: data, encoding: encoding ?? .utf8)
    }
    
    override func stream() -> InputStream? {
        return InputStream(data: data)
    }
    
}
