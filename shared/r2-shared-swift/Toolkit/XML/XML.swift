//
//  XML.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 15/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import Fuzi

typealias XMLNamespace = (prefix: String, uri: String)

protocol XMLNode {
    
    /// Concatenated string content of all descendants.
    var textContent: String? { get }
    
    /// Finds the first element matching the given XPath expression.
    func first(_ xpath: String, with namespaces: [XMLNamespace]) -> XMLElement?
    
    /// Finds all the elemens matching the given XPath expression.
    func all(_ xpath: String, with namespaces: [XMLNamespace]) -> [XMLElement]
    
}

extension XMLNode {
    
    func first(_ xpath: String) -> XMLElement? {
        return first(xpath, with: [])
    }
    
    func all(_ xpath: String) -> [XMLElement] {
        return all(xpath, with: [])
    }
    
}

protocol XMLDocument: XMLNode {

    /// Creates an `XMLDocument`.
    ///
    /// - Parameters:
    ///   - string: XML string representation.
    ///   - namespaces: List of namespace prefixes to declare in the document.
    init?(string: String, namespaces: [XMLNamespace])
    
    /// Root element in the XML document.
    var documentElement: XMLElement? { get }

}

extension XMLDocument {
    
    init?(string: String) {
        self.init(string: string, namespaces: [])
    }
    
}

protocol XMLElement: XMLNode {

    /// Returns the element tag name without its prefix, and with the original case.
    /// You should uppercase/lowercase it to perform comparisons.
    var localName: String { get }

    /// Returns the attribute with the given `qualifiedName`, e.g. `opf:role`.
    func attribute(named qualifiedName: String) -> String?

    /// Returns the attribute with the given `localName` and `namespace`.
    /// For example, with `opf:role`: `role` and `http://www.idpf.org/2007/opf`
    func attribute(named localName: String, namespace: String?) -> String?

}
