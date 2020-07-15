//
//  ReadiumWebPubParser.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 25.06.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

public enum ReadiumWebPubParserError: Error {
    case parseFailure(url: URL, Error?)
    case missingFile(path: String)
}

/// Parser for a Readium Web Publication (packaged, or as a manifest).
public class ReadiumWebPubParser: PublicationParser, Loggable {
    
    public enum Error: Swift.Error {
        case manifestNotFound
    }
    
    public func parse(file: File, fetcher: Fetcher, fallbackTitle: String, warnings: WarningLogger?) throws -> Publication.Components? {
        guard let format = file.format, format.mediaType.isReadiumWebPubProfile else {
            return nil
        }
        
        if format.mediaType.isRWPM {
            return try parseManifest(at: file, from: fetcher, format: format, warnings: warnings)
        } else {
            return try parsePackage(at: file, from: fetcher, format: format, warnings: warnings)
        }
    }

    private func parseManifest(at file: File, from fetcher: Fetcher, format: Format, warnings: WarningLogger?) throws -> Publication.Components? {
        guard
            let manifestLink = fetcher.links.first,
            let manifestData = try? fetcher.get(manifestLink).read().get() else
        {
            throw Error.manifestNotFound
        }
        
        // We discard the `fetcher` provided by the Streamer, because it was only used to read the
        // manifest file. We use an `HTTPFetcher` instead to serve the remote resources.
        let fetcher = HTTPFetcher()
        return try parsePublication(fromManifest: manifestData, in: fetcher, file: file, format: format, isPackage: false)
    }
    
    private func parsePackage(at file: File, from fetcher: Fetcher, format: Format, warnings: WarningLogger?) throws -> Publication.Components? {
        guard let manifestData = try? fetcher.readData(at: "/manifest.json") else {
            throw Error.manifestNotFound
        }
        return try parsePublication(fromManifest: manifestData, in: fetcher, file: file, format: format, isPackage: true)
    }
    
    private func parsePublication(fromManifest manifestData: Data, in fetcher: Fetcher, file: File, format: Format, isPackage: Bool) throws -> Publication.Components? {
        return try Publication.Components(
            fileFormat: format,
            publicationFormat: .webpub,
            manifest: Manifest(
                json: JSONSerialization.jsonObject(with: manifestData),
                normalizeHref: { normalize(base: "/", href: $0) }
            ),
            fetcher: fetcher
        )
    }

    @available(*, deprecated, message: "Use the other `parse` method instead")
    public static func parse(at url: URL) throws -> (PubBox, PubParsingCallback) {
        let file = File(url: url)
        guard
            let format = file.format,
            let fetcher = try? makeFetcher(for: url),
            let components = try? ReadiumWebPubParser().parse(file: file, fetcher: fetcher) else
        {
            throw ReadiumWebPubParserError.parseFailure(url: url, nil)
        }
        
        let publication = components.build()
        let container = PublicationContainer(
            publication: publication,
            path: url.path,
            mimetype: format.mediaType.string
        )

        return ((publication, container), { _ in })
    }

}

@available(*, deprecated, renamed: "ReadiumWebPubParserError")
public typealias WEBPUBParserError = ReadiumWebPubParserError

@available(*, deprecated, renamed: "ReadiumWebPubParser")
public typealias WEBPUBParser = ReadiumWebPubParser
