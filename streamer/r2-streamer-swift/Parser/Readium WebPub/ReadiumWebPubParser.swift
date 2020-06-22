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
            var container: Container = HTTPContainer(baseURL: url.deletingLastPathComponent(), mimetype: MediaType.readiumWebPubManifest.string)
            let publication = try parsePublication(fromManifest: data, in: &container, sourceURL: url, format: format, isPackage: false)

            func didLoadDRM(drm: DRM?) {
                container.drm = drm
            }
            
            return ((publication, container), didLoadDRM)
            
        } catch {
            throw ReadiumWebPubParserError.parseFailure(url: url, error)
        }
    }
    
    private static func parsePackage(at url: URL, format: Format) throws -> (PubBox, PubParsingCallback) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
            var container: Container = isDirectory.boolValue
                ? DirectoryContainer(directory: url.path, mimetype: MediaType.readiumWebPub.string)
                : ArchiveContainer(path: url.path, mimetype: MediaType.readiumWebPub.string) else
        {
            throw ReadiumWebPubParserError.missingFile(path: url.path)
        }
        
        guard let manifestData = try? container.data(relativePath: manifestPath) else {
            throw ReadiumWebPubParserError.missingFile(path: manifestPath)
        }
        
        let publication = try parsePublication(fromManifest: manifestData, in: &container, sourceURL: url, format: format, isPackage: true)
        container.rootFile.rootFilePath = manifestPath

        func didLoadDRM(drm: DRM?) {
            container.drm = drm
        }
        
        return ((publication, container), didLoadDRM)
    }
    
    private static func parsePublication(fromManifest manifestData: Data, in container: inout Container, sourceURL: URL, format: Format, isPackage: Bool) throws -> Publication {
        do {
            let lcpProtected = (isPackage && isProtectedWithLCP(container))
            if lcpProtected {
                container.drm = DRM(brand: .lcp)
            }
            
            let json = try JSONSerialization.jsonObject(with: manifestData)
            let publication = try Publication(json: json, normalizeHref: { normalize(base: "/", href: $0) })
            
            publication.format = .webpub
            container.rootFile.mimetype = format.mediaType.string

            return publication

        } catch {
            throw ReadiumWebPubParserError.parseFailure(url: sourceURL, error)
        }
    }

    private static func isProtectedWithLCP(_ container: Container) -> Bool {
        return (try? container.data(relativePath: "license.lcpl")) != nil
    }

}

@available(*, deprecated, renamed: "ReadiumWebPubParserError")
public typealias WEBPUBParserError = ReadiumWebPubParserError

@available(*, deprecated, renamed: "ReadiumWebPubParser")
public typealias WEBPUBParser = ReadiumWebPubParser
