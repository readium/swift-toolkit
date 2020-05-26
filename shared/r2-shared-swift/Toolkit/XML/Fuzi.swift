//
//  Fuzi.swift
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

final class FuziXMLDocument: XMLDocument, Loggable {
    
    fileprivate let document: Fuzi.XMLDocument
    
    init?(string: String, namespaces: [XMLNamespace]) {
        do {
            self.document = try Fuzi.XMLDocument(string: string)
        } catch {
            Self.log(.error, error)
            return nil
        }
    }
    
    lazy var documentElement: XMLElement? =
        document.root.map { FuziXMLElement(document: document, element: $0) }

    var textContent: String? {
        return document.root?.stringValue
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
        return element.attr(qualifiedName)
    }
    
    func attribute(named localName: String, namespace: String?) -> String? {
        return element.attr(localName, namespace: namespace)
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
