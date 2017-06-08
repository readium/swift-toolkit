//
//  MultilangString.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/30/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import AEXML

extension MultilangString: Loggable {}

/// `MultilangString` is designed to containe : a`singleString` (the
/// mainTitle) and possiby a `multiString` (the mainTitle + the altTitles).
/// It's mainly here for the JSON serialisation, depending if we need a simple
/// String or an array depending of the situation.
public class MultilangString {
    /// Contains the main denomination.
    public var singleString: String?
    /// Contains the alternatives denominations and keyed by language codes, if any.
    public var multiString =  [String: String]()

    public init() {}

    /// Fills the `multiString` dictionnary property.
    ///
    ///
    /// - Parameters:
    ///   - element: The element to parse (can be a title or a contributor).
    ///   - metadata: The metadata XML element.
    public func fillMultiString(forElement element: AEXMLElement,
                                _ metadata: AEXMLElement)
    {
        guard let elementId = element.attributes["id"] else {
            return
        }
        // Find the <meta refines="elementId" property="alternate-script">
        // in order to find the alternative strings, if any.
        let attr = ["refines": "#\(elementId)", "property": "alternate-script"]
        guard let altScriptMetas = metadata["meta"].all(withAttributes: attr) else {
            return
        }
        // For each alt meta element.
        for altScriptMeta in altScriptMetas {
            // If it have a value then add it to the multiString dictionnary.
            guard let title = altScriptMeta.value,
                let lang = altScriptMeta.attributes["xml:lang"] else {
                    continue
            }
            multiString[lang] = title
        }
        // If we have 'alternates'...
        if !multiString.isEmpty {
            let publicationDefaultLanguage = metadata["dc:language"].value ?? ""
            let lang = element.attributes["xml:lang"] ?? publicationDefaultLanguage
            let value = element.value

            // Add the main element to the dictionnary.
            multiString[lang] = value
        }
    }
}
