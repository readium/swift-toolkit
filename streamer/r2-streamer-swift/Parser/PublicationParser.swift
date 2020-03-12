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


public protocol PublicationParser {
    
    static func parse(at url: URL) throws -> (PubBox, PubParsingCallback)
    
    // Deprecated: use `parse(url:)` instead
    static func parse(fileAtPath path: String) throws -> (PubBox, PubParsingCallback)

}

extension PublicationParser {
    
    public static func parse(fileAtPath path: String) throws -> (PubBox, PubParsingCallback) {
        return try parse(at: URL(fileURLWithPath: path))
    }
    
}


public extension Publication {
    
    static func parse(at url: URL) throws -> (PubBox, PubParsingCallback)? {
        let parsers: [Format: PublicationParser.Type] = [
            .cbz: CbzParser.self,
            .epub: EpubParser.self,
            .pdf: PDFParser.self,
            .webpub: ReadiumParser.self,
            .audiobook: ReadiumParser.self
        ]

        let format = Format(file: url)
        guard let parser = parsers[format] else {
            return nil
        }
        
        return try parser.parse(at: url)
    }
    
}


/// Normalize a path relative path given the base path.
internal func normalize(base: String, href: String?) -> String {
    guard let href = href, !href.isEmpty else {
        return ""
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
