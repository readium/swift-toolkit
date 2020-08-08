//
//  CBZParser.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri on 3/31/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

public enum CBZParserError: Error {
    case invalidCBZ(path: String)
}

@available(*, deprecated, renamed: "CBZParserError")
public typealias CbzParserError = CBZParserError

/// CBZ publication parsing class.
@available(*, deprecated, message: "Use `ImageParser` instead")
public class CbzParser: PublicationParser {
    
    public func parse(file: File, fetcher: Fetcher, warnings: WarningLogger?) throws -> Publication.Builder? {
        return try ImageParser().parse(file: file, fetcher: fetcher, warnings: warnings)
    }

    /// Parse the Comic Book Archive at given `url` and return a `PubBox` object containing
    /// the resulting `Publication` and `Container` objects.
    public static func parse(at url: URL) throws -> (PubBox, PubParsingCallback) {
        guard
            let fetcher = try? makeFetcher(for: url),
            let components = try? ImageParser().parse(file: File(url: url), fetcher: fetcher) else
        {
            throw CBZParserError.invalidCBZ(path: url.path)
        }

        let publication = components.build()
        let container = PublicationContainer(publication: publication, path: url.path, mimetype: MediaType.cbz.string)
        return ((publication, container), { _ in })
    }

    @available(*, unavailable, message: "Use the other `parse()` method.")
    public func parse(fileAtPath path: String) throws -> PubBox {
        fatalError("Not available.")
    }

}
