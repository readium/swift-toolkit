//
//  WebPubParser.swift
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
    
    /// Path of the RWPM in a ZIP package.
    private static let manifestPath = "manifest.json"

    public static func parse(at url: URL) throws -> (PubBox, PubParsingCallback) {
        guard let format = Format.of(url) else {
            log(.error, "Can't determine the file format of \(url)")
            throw ReadiumWebPubParserError.parseFailure(url: url, nil)
        }

        if format.mediaType.isRWPM {
            return try parseManifest(at: url, format: format)
        } else {
            return try parsePackage(at: url, format: format)
        }
    }
    
    public static func parseManifest(at url: URL, format: Format) throws -> (PubBox, PubParsingCallback) {
        do {
            let data = try Data(contentsOf: url)
            let fetcher = HTTPFetcher(baseURL: url.deletingLastPathComponent())
            return try parsePublication(fromManifest: data, in: fetcher, sourceURL: url, format: format, isPackage: false)

        } catch {
            throw ReadiumWebPubParserError.parseFailure(url: url, error)
        }
    }
    
    private static func parsePackage(at url: URL, format: Format) throws -> (PubBox, PubParsingCallback) {
        let fetcher = try ArchiveFetcher(url: url)
        guard let manifestData = try? fetcher.readData(at: manifestPath) else {
            throw ReadiumWebPubParserError.missingFile(path: manifestPath)
        }
        
        return try parsePublication(fromManifest: manifestData, in: fetcher, sourceURL: url, format: format, isPackage: true)
    }
    
    private static func parsePublication(fromManifest manifestData: Data, in fetcher: Fetcher, sourceURL: URL, format: Format, isPackage: Bool) throws -> (PubBox, PubParsingCallback) {
        do {
            var fetcher = fetcher
            
            var decryptor: LCPDecryptor?
            let lcpProtected = (isPackage && isProtectedWithLCP(fetcher))
            if lcpProtected {
                decryptor = LCPDecryptor()
                fetcher = TransformingFetcher(fetcher: fetcher, transformer: decryptor!.decrypt)
            }
            
            let publication = try Publication(
                manifest: Manifest(
                    json: JSONSerialization.jsonObject(with: manifestData),
                    normalizeHref: { normalize(base: "/", href: $0) }
                ),
                fetcher: fetcher,
                format: .webpub
            )

            let container = PublicationContainer(
                publication: publication,
                path: sourceURL.path,
                mimetype: format.mediaType.string,
                drm: lcpProtected ? DRM(brand: .lcp) : nil
            )

            func didLoadDRM(drm: DRM?) {
                container.drm = drm
                decryptor?.license = drm?.license
            }
            
            return ((publication, container), didLoadDRM)

        } catch {
            throw ReadiumWebPubParserError.parseFailure(url: sourceURL, error)
        }
    }

    private static func isProtectedWithLCP(_ fetcher: Fetcher) -> Bool {
        return (try? fetcher.readData(at: "license.lcpl")) != nil
    }

}

@available(*, deprecated, renamed: "ReadiumWebPubParserError")
public typealias WEBPUBParserError = ReadiumWebPubParserError

@available(*, deprecated, renamed: "ReadiumWebPubParser")
public typealias WEBPUBParser = ReadiumWebPubParser
