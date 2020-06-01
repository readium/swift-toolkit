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
public class CbzParser: PublicationParser {

    @available(*, deprecated, message: "Use the static method `CbzParser.parse()` instead of instantiationg `CbzParser`")
    public init() {}

    @available(*, deprecated, message: "Use the static method `CbzParser.parse()` instead of instantiationg `CbzParser`")
    public func parse(fileAtPath path: String) throws -> PubBox {
        // For legacy reason this parser used to be instantiated, compared to EPUBParser
        return try CbzParser.parse(fileAtPath: path).0
    }
    
    /// Parse the Comic Book Archive at given `url` and return a `PubBox` object containing
    /// the resulting `Publication` and `Container` objects.
    public static func parse(at url: URL) throws -> (PubBox, PubParsingCallback) {
        guard
            let fetcher = ArchiveFetcher.make(archiveOrDirectory: url),
            let manifest = parseManifest(in: fetcher, at: url) else
        {
            throw CBZParserError.invalidCBZ(path: url.path)
        }
        
        let publication = Publication(
            manifest: manifest,
            fetcher: fetcher,
            servicesBuilder: PublicationServicesBuilder {
                $0.setPositions(PerResourcePositionsService.create(fallbackMediaType: "image/*"))
            },
            format: .cbz
        )
        
        let container = PublicationContainer(publication: publication, path: url.path, mimetype: MediaType.cbz.string)
        
        return ((publication, container), { _ in })
    }
    
    private static func parseManifest(in fetcher: Fetcher, at url: URL) -> PublicationManifest? {
        var readingOrder = fetcher.links
            .filter { $0.mediaType?.isBitmap == true }
            .sorted { lhs, rhs in lhs.href < rhs.href }
        
        guard !readingOrder.isEmpty else {
            return nil
        }
        
        // First valid resource is the cover.
        readingOrder[0] = readingOrder[0].copy(rels: ["cover"])
        
        return PublicationManifest(
            metadata: Metadata(
                title: url.title
            ),
            readingOrder: readingOrder
        )
    }

}
