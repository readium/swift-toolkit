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
    public var singleString: String?
    public var multiString =  [String: String]()

    /// <#Description#>
    ///
    /// - Parameters:
    ///   - element: <#element description#>
    ///   - metadata: <#metadata description#>
    public func fillMultiString(forElement element: AEXMLElement, _ metadata: AEXMLElement) {
        guard let elementId = element.attributes["id"] else {
            return
        }
        let altScriptAttribute = ["refines": "#\(elementId)", "property": "alternate-script"]

        // Find the <meta refines="elementId" property="alternate-script">
        // in order to find the alternative strings, if any.
        guard let altScriptMetas = metadata["meta"].all(withAttributes: altScriptAttribute) else {
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
