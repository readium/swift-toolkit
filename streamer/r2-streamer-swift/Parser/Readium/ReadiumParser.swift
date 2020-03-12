//
//  ReadiumParser.swift
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

public enum ReadiumParserError: Error {
    case parseFailure(url: URL, Error)
    case missingFile(path: String)
}

/// Parser for a Readium Web Publication (packaged, or as a manifest).
public class ReadiumParser: PublicationParser {
    
    private static let webpubMediaType = "application/webpub+zip"
    private static let webpubManifestMediaType = "application/webpub+json"
    private static let audiobookMediaType = "application/audiobook+json"
    private static let audiobookManifestMediaType = "application/audiobook+json"
    private static let lcpProtectedAudiobookMediaType = "application/audiobook+lcp"

    public static func parse(at url: URL) throws -> (PubBox, PubParsingCallback) {
        if url.isFileURL && !["json", "audiobook-manifest"].contains(url.pathExtension.lowercased()) {
            return try parsePackage(at: url)
        } else {
            return try parseManifest(at: url)
        }
    }
    
    public static func parseManifest(at url: URL) throws -> (PubBox, PubParsingCallback) {
        do {
            let data = try Data(contentsOf: url)
            var container: Container = HTTPContainer(baseURL: url.deletingLastPathComponent(), mimetype: webpubManifestMediaType)
            let publication = try parsePublication(fromManifest: data, in: &container, sourceURL: url, isPackage: false)

            func didLoadDRM(drm: DRM?) {
                container.drm = drm
            }
            
            return ((publication, container), didLoadDRM)
            
        } catch {
            throw ReadiumParserError.parseFailure(url: url, error)
        }
    }
    
    private static func parsePackage(at url: URL) throws -> (PubBox, PubParsingCallback) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
            var container: Container = isDirectory.boolValue
                ? DirectoryContainer(directory: url.path, mimetype: webpubMediaType)
                : ArchiveContainer(path: url.path, mimetype: webpubMediaType) else
        {
            throw ReadiumParserError.missingFile(path: url.path)
        }
        
        guard let manifestData = try? container.data(relativePath: "manifest.json") else {
            throw ReadiumParserError.missingFile(path: "manifest.json")
        }
        
        let publication = try parsePublication(fromManifest: manifestData, in: &container, sourceURL: url, isPackage: true)

        func didLoadDRM(drm: DRM?) {
            container.drm = drm
        }
        
        return ((publication, container), didLoadDRM)
    }
    
    private static func parsePublication(fromManifest manifestData: Data, in container: inout Container, sourceURL: URL, isPackage: Bool) throws -> Publication {
        do {
            let lcpProtected = (isPackage && isProtectedWithLCP(container))
            if lcpProtected {
                container.drm = DRM(brand: .lcp)
            }
            
            let json = try JSONSerialization.jsonObject(with: manifestData)
            let publication = try Publication(json: json)
            
            let (format, mediaType) = parseFormat(of: publication, at: sourceURL, isPackage: isPackage, isProtectedWithLCP: lcpProtected)
            
            publication.format = format
            container.rootFile.mimetype = mediaType

            return publication

        } catch {
            throw ReadiumParserError.parseFailure(url: sourceURL, error)
        }
    }
    
    private static func parseFormat(of publication: Publication, at url: URL, isPackage: Bool, isProtectedWithLCP: Bool) -> (format: Publication.Format, mediaType: String) {
        let selfMediaType = publication.link(withRel: "self")?.type
        if selfMediaType == audiobookManifestMediaType
            || publication.metadata.type == "http://schema.org/Audiobook"
            || ["audiobook", "audiobook-manifest"].contains(url.pathExtension.lowercased())
        {
            return (.audiobook, mediaType: isPackage
                ? (isProtectedWithLCP ? lcpProtectedAudiobookMediaType : audiobookMediaType)
                : audiobookManifestMediaType
            )
        } else {
            return (.webpub, mediaType: isPackage ? webpubMediaType : webpubManifestMediaType)
        }
    }
    
    private static func isProtectedWithLCP(_ container: Container) -> Bool {
        return (try? container.data(relativePath: "license.lcpl")) != nil
    }

}

@available(*, deprecated, renamed: "ReadiumParserError")
public typealias WEBPUBParserError = ReadiumParserError

@available(*, deprecated, renamed: "ReadiumParserError")
public typealias WEBPUBParser = ReadiumParser
