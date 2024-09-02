//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import Fuzi

final class FuziXMLDocument: XMLDocument, Loggable {
    enum ParseError: Error {
        case notAnXML
    }

    fileprivate let document: Fuzi.XMLDocument

    convenience init(data: Data, namespaces: [XMLNamespace]) throws {
        try self.init(document: Fuzi.XMLDocument(data: data), namespaces: namespaces)
    }

    convenience init(string: String, namespaces: [XMLNamespace]) throws {
        try self.init(document: Fuzi.XMLDocument(string: string), namespaces: namespaces)
    }

    init(document: Fuzi.XMLDocument, namespaces: [XMLNamespace]) throws {
        guard document.root != nil else {
            throw ParseError.notAnXML
        }

        document.definePrefixes(namespaces)
        self.document = document
    }

    lazy var documentElement: XMLElement? =
        document.root.map { FuziXMLElement(document: document, element: $0) }

    var textContent: String? {
        document.root?.stringValue
    }

    func first(_ xpath: String, with namespaces: [XMLNamespace]) -> XMLElement? {
        document.definePrefixes(namespaces)
        return document.firstChild(xpath: xpath).map { FuziXMLElement(document: document, element: $0) }
    }

    func all(_ xpath: String, with namespaces: [XMLNamespace]) -> [XMLElement] {
        document.definePrefixes(namespaces)
        return document.xpath(xpath).map { FuziXMLElement(document: document, element: $0) }
    }
}

final class FuziXMLElement: XMLElement, Loggable {
    fileprivate let document: Fuzi.XMLDocument
    fileprivate let element: Fuzi.XMLElement

    fileprivate init(document: Fuzi.XMLDocument, element: Fuzi.XMLElement) {
        self.document = document
        self.element = element
    }

    var localName: String {
        element.tag ?? ""
    }

    var textContent: String? {
        element.stringValue
    }

    func attribute(named qualifiedName: String) -> String? {
        element.attr(qualifiedName)
    }

    func attribute(named localName: String, namespace: String?) -> String? {
        element.attr(localName, namespace: namespace)
    }

    func first(_ xpath: String, with namespaces: [XMLNamespace]) -> XMLElement? {
        document.definePrefixes(namespaces)
        return element.firstChild(xpath: xpath).map { FuziXMLElement(document: document, element: $0) }
    }

    func all(_ xpath: String, with namespaces: [XMLNamespace]) -> [XMLElement] {
        document.definePrefixes(namespaces)
        return element.xpath(xpath).map { FuziXMLElement(document: document, element: $0) }
    }
}

private extension Fuzi.XMLDocument {
    func definePrefixes(_ namespaces: [XMLNamespace]) {
        for namespace in namespaces {
            definePrefix(namespace.prefix, forNamespace: namespace.uri)
        }
    }
}
