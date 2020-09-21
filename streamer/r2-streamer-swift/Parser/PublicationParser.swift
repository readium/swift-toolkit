//
//  PublicationParser.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri on 4/4/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared


/// `Publication` and the associated `Container`.
@available(*, deprecated, message: "Use an instance of `Streamer` to open a `Publication`")
public typealias PubBox = (publication: Publication, associatedContainer: Container)
/// A callback called when the publication license is loaded in the given DRM object.
public typealias PubParsingCallback = (DRM?) throws -> Void


/// Parses a Publication from a file.
public protocol PublicationParser {
    
    /// Constructs a `Publication.Builder` to build a `Publication` from a publication file.
    ///
    /// - Parameters:
    ///   - file: Path to the publication file.
    ///   - fetcher: Initial leaf fetcher which should be used to read the publication's resources.
    ///     This can be used to:
    ///       - support content protection technologies
    ///       - parse exploded archives or in archiving formats unknown to the parser, e.g. RAR
    ///     If the file is not an archive, it will be reachable at the HREF /<file.name>.
    ///   - warnings: Used to report non-fatal parsing warnings, such as publication authoring
    ///     mistakes. This is useful to warn users of potential rendering issues or help authors
    ///     debug their publications.
    func parse(file: File, fetcher: Fetcher, warnings: WarningLogger?) throws -> Publication.Builder?
    
    // Deprecated: use `parse(file:fetcher:warnings)` instead
    @available(*, deprecated, message: "Use an instance of `Streamer` to open a `Publication`")
    static func parse(at url: URL) throws -> (PubBox, PubParsingCallback)
    // Deprecated: use `parse(file:fetcher:warnings)` instead
    @available(*, deprecated, message: "Use an instance of `Streamer` to open a `Publication`")
    static func parse(fileAtPath path: String) throws -> (PubBox, PubParsingCallback)

}

extension PublicationParser {
    
    func parse(file: File, fetcher: Fetcher, warnings: WarningLogger? = nil) throws -> Publication.Builder? {
        return try parse(file: file, fetcher: fetcher, warnings: warnings)
    }
    
    @available(*, deprecated, message: "Use an instance of `Streamer` to open a `Publication`")
    public static func parse(fileAtPath path: String) throws -> (PubBox, PubParsingCallback) {
        return try parse(at: URL(fileURLWithPath: path))
    }
    
}


public extension Publication {
    
    @available(*, deprecated, message: "Use an instance of `Streamer` to parse a publication")
    static func parse(at url: URL) throws -> (PubBox, PubParsingCallback)? {
        guard let format = R2Shared.Format.of(url) else {
            return nil
        }

        let parser: PublicationParser.Type? = {
            switch format {
            case .cbz:
                return CbzParser.self
            case .epub:
                return EPUBParser.self
            case .pdf, .lcpProtectedPDF:
                return PDFParser.self
            case .readiumWebPub, .readiumWebPubManifest, .readiumAudiobook, .readiumAudiobookManifest, .lcpProtectedAudiobook, .divina, .divinaManifest:
                return ReadiumWebPubParser.self
            default:
                return nil
            }
        }()
        return try parser?.parse(at: url)
    }
    
}
