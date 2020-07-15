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
    ///   - fallbackTitle: Publication's title is mandatory, but some formats might not have a way
    ///     of declaring a title. In which case, `fallbackTitle` will be used.
    ///   - warnings: Used to report non-fatal parsing warnings, such as publication authoring
    ///     mistakes. This is useful to warn users of potential rendering issues or help authors
    ///     debug their publications.
    func parse(file: File, fetcher: Fetcher, fallbackTitle: String, warnings: WarningLogger?) throws -> Publication.Components?
    
    // Deprecated: use `parse(file:fetcher:fallbackTitle:warnings)` instead
    static func parse(at url: URL) throws -> (PubBox, PubParsingCallback)
    // Deprecated: use `parse(file:fetcher:fallbackTitle:warnings)` instead
    static func parse(fileAtPath path: String) throws -> (PubBox, PubParsingCallback)

}

extension PublicationParser {
    
    func parse(file: File, fetcher: Fetcher, fallbackTitle: String? = nil, warnings: WarningLogger? = nil) throws -> Publication.Components? {
        return try parse(file: file, fetcher: fetcher, fallbackTitle: fallbackTitle ?? file.name, warnings: warnings)
    }
    
    public static func parse(fileAtPath path: String) throws -> (PubBox, PubParsingCallback) {
        return try parse(at: URL(fileURLWithPath: path))
    }
    
}


public extension Publication {
    
    static func parse(at url: URL) throws -> (PubBox, PubParsingCallback)? {
        guard let format = R2Shared.Format.of(url) else {
            return nil
        }

        let parser: PublicationParser.Type? = {
            switch format {
            case .cbz:
                return CbzParser.self
            case .epub:
                return EpubParser.self
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


/// Normalize a path relative path given the base path.
internal func normalize(base: String, href: String?) -> String {
    guard let href = href, !href.isEmpty else {
        return ""
    }
    if let url = URL(string: href), url.scheme != nil {
        return href
    }
    
    let hrefComponents = href.components(separatedBy: "/").filter({!$0.isEmpty})
    var baseComponents = base.components(separatedBy: "/").filter({!$0.isEmpty})

    // Remove the /folder/folder/"PATH.extension" part to keep only the path.
    _ = baseComponents.popLast()
    // Find the number of ".." in the path to replace them.
    let replacementsNumber = hrefComponents.filter({$0 == ".."}).count
    // Get the valid part of href, reversed for next operation.
    var normalizedComponents = hrefComponents.filter({$0 != ".."})
    // Add the part from base to replace the "..".
    for _ in 0..<replacementsNumber {
        _ = baseComponents.popLast()
    }
    normalizedComponents = baseComponents + normalizedComponents
    // Recreate a string.
    var normalizedString = ""
    for component in normalizedComponents {
        normalizedString.append("/\(component)")
    }
    return normalizedString
}
