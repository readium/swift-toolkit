//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public struct XMLNamespace {
    public let prefix: String
    public let uri: String

    public static let adept = XMLNamespace(prefix: "adept", uri: "http://ns.adobe.com/adept")
    public static let atom = XMLNamespace(prefix: "atom", uri: "http://www.w3.org/2005/Atom")
    public static let cn = XMLNamespace(prefix: "cn", uri: "urn:oasis:names:tc:opendocument:xmlns:container")
    public static let comp = XMLNamespace(prefix: "comp", uri: "http://www.idpf.org/2016/encryption#compression")
    public static let dc = XMLNamespace(prefix: "dc", uri: "http://purl.org/dc/elements/1.1/")
    public static let dcterms = XMLNamespace(prefix: "dcterms", uri: "http://purl.org/dc/terms/")
    public static let ds = XMLNamespace(prefix: "ds", uri: "http://www.w3.org/2000/09/xmldsig#")
    public static let enc = XMLNamespace(prefix: "enc", uri: "http://www.w3.org/2001/04/xmlenc#")
    public static let epub = XMLNamespace(prefix: "epub", uri: "http://www.idpf.org/2007/ops")
    public static let html = XMLNamespace(prefix: "html", uri: "http://www.w3.org/1999/xhtml")
    public static let ncx = XMLNamespace(prefix: "ncx", uri: "http://www.daisy.org/z3986/2005/ncx/")
    public static let opds = XMLNamespace(prefix: "opds", uri: "http://opds-spec.org/2010/catalog")
    public static let opf = XMLNamespace(prefix: "opf", uri: "http://www.idpf.org/2007/opf")
    public static let rendition = XMLNamespace(prefix: "rendition", uri: "http://www.idpf.org/2013/rendition")
    public static let sig = XMLNamespace(prefix: "sig", uri: "http://www.w3.org/2000/09/xmldsig#")
    public static let smil = XMLNamespace(prefix: "smil", uri: "http://www.w3.org/ns/SMIL")
    public static let thr = XMLNamespace(prefix: "thr", uri: "http://purl.org/syndication/thread/1.0")
    public static let xhtml = XMLNamespace(prefix: "xhtml", uri: "http://www.w3.org/1999/xhtml")
    public static let xhtml2 = XMLNamespace(prefix: "xhtml2", uri: "http://www.w3.org/2002/06/xhtml2")
}

public protocol XMLNode {
    /// Concatenated string content of all descendants.
    var textContent: String? { get }

    /// Finds the first element matching the given XPath expression.
    func first(_ xpath: String, with namespaces: [XMLNamespace]) -> XMLElement?

    /// Finds all the elemens matching the given XPath expression.
    func all(_ xpath: String, with namespaces: [XMLNamespace]) -> [XMLElement]
}

public extension XMLNode {
    func first(_ xpath: String) -> XMLElement? {
        first(xpath, with: [])
    }

    func all(_ xpath: String) -> [XMLElement] {
        all(xpath, with: [])
    }
}

public protocol XMLDocument: XMLNode {
    /// Root element in the XML document.
    var documentElement: XMLElement? { get }
}

public protocol XMLElement: XMLNode {
    /// Returns the element tag name without its prefix, and with the original case.
    /// You should uppercase/lowercase it to perform comparisons.
    var localName: String { get }

    /// Returns the attribute with the given `qualifiedName`, e.g. `opf:role`.
    func attribute(named qualifiedName: String) -> String?

    /// Returns the attribute with the given `localName` and `namespace`.
    /// For example, with `opf:role`: `role` and `http://www.idpf.org/2007/opf`
    func attribute(named localName: String, namespace: String?) -> String?
}

public protocol XMLDocumentFactory {
    /// Opens an XML document from a local file path.
    ///
    /// - Parameter namespaces: List of namespace prefixes to declare in the document.
    func open(file: FileURL, namespaces: [XMLNamespace]) async throws -> XMLDocument

    /// Opens an XML document from its raw data content.
    ///
    /// - Parameter namespaces: List of namespace prefixes to declare in the document.
    func open(data: Data, namespaces: [XMLNamespace]) async throws -> XMLDocument

    /// Opens an XML document from its raw string content.
    ///
    /// - Parameter namespaces: List of namespace prefixes to declare in the document.
    func open(string: String, namespaces: [XMLNamespace]) async throws -> XMLDocument
}

public class DefaultXMLDocumentFactory: XMLDocumentFactory, Loggable {
    public init() {}

    public func open(file: FileURL, namespaces: [XMLNamespace]) async throws -> XMLDocument {
        warnIfMainThread()
        return try await open(string: String(contentsOf: file.url), namespaces: namespaces)
    }

    public func open(string: String, namespaces: [XMLNamespace]) async throws -> XMLDocument {
        try FuziXMLDocument(string: string, namespaces: namespaces)
    }

    public func open(data: Data, namespaces: [XMLNamespace]) async throws -> XMLDocument {
        try FuziXMLDocument(data: data, namespaces: namespaces)
    }
}
