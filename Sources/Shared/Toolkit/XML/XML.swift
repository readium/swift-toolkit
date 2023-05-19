//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

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
        first(xpath, with: [])
    }

    func all(_ xpath: String) -> [XMLElement] {
        all(xpath, with: [])
    }
}

protocol XMLDocument: XMLNode {
    /// Root element in the XML document.
    var documentElement: XMLElement? { get }
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

protocol XMLDocumentFactory {
    /// Opens an XML document from a local file path.
    ///
    /// - Parameter namespaces: List of namespace prefixes to declare in the document.
    func open(url: URL, namespaces: [XMLNamespace]) throws -> XMLDocument

    /// Opens an XML document from its raw string content.
    ///
    /// - Parameter namespaces: List of namespace prefixes to declare in the document.
    func open(string: String, namespaces: [XMLNamespace]) throws -> XMLDocument
}

class DefaultXMLDocumentFactory: XMLDocumentFactory, Loggable {
    init() {}

    func open(url: URL, namespaces: [XMLNamespace]) throws -> XMLDocument {
        warnIfMainThread()
        return try open(string: String(contentsOf: url), namespaces: namespaces)
    }

    func open(string: String, namespaces: [XMLNamespace]) throws -> XMLDocument {
        try FuziXMLDocument(string: string, namespaces: namespaces)
    }
}
