//
//  NCXParser.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri on 3/17/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import R2Shared
import AEXML

/// From IDPF a11y-guidelines content/nav/toc.html :
/// "The NCX file is allowed for forwards compatibility purposes only. An EPUB 2
/// reading systems may open an EPUB 3 publication, but it will not be able to 
/// use the new navigation document format.
/// You can ignore the NCX file if your book won't render properly as EPUB 2 
/// content, or if you aren't targeting cross-compatibility."
final class NCXParser {
    
    enum NavType: String {
        case tableOfContents = "navMap"
        case pageList = "pageList"
    }
    
    private let data: Data
    private let path: String
    
    /// Builds the NCX parser from the NCX data and its path. The path is used to normalize the links' hrefs.
    init(data: Data, at path: String) {
        self.data = data
        self.path = path
    }
    
    private lazy var document: AEXMLDocument? = {
        return try? AEXMLDocument(xml: data)
    }()
    
//    private lazy var document: XMLDocument? = {
//        // Warning: Somehow if we use HTMLDocument instead of XMLDocument, then the `epub` prefix doesn't work.
//        let document = try? XMLDocument(data: data)
//        document?.definePrefix("html", defaultNamespace: "http://www.w3.org/1999/xhtml")
//        document?.definePrefix("epub", defaultNamespace: "http://www.idpf.org/2007/ops")
//        return document
//    }()
    
    /// Returns the data representation of the table of contents (toc) informations contained in the NCX Document.
    var tableOfContents: [Link] {
        guard let document = document else {
            return []
        }
        let navMapElement = document["ncx"]["navMap"]
        let tableOfContentsNodes = nodeArray(forNcxElement: navMapElement, ofType: "navPoint")
        return tableOfContentsNodes
    }

    /// Returns the data representation of the pageList informations contained in the NCX Document.
    var pageList: [Link] {
        guard let document = document else {
            return []
        }
        let pageListElement = document["ncx"]["pageList"]
        let pageListNodes = nodeArray(forNcxElement: pageListElement, ofType: "pageTarget")
        return pageListNodes
    }

    // TODO: Navlist parsing (all the remaining elements, landmarks etc).

    // MARK: Fileprivate Methods.

    /// Generate an array of Link elements representing the XML structure of the
    /// given NCX element. Each of them possibly having children.
    ///
    /// - Parameters:
    ///   - ncxElement: The NCX XML element Object.
    ///   - type: The sub elements names (e.g. 'navPoint' for 'navMap',
    ///           'pageTarget' for 'pageList'.
    /// - Returns: The Object representation of the data contained in the given
    ///            NCX XML element.
    private func nodeArray(forNcxElement element: AEXMLElement, ofType type: String) -> [Link]
    {
        return (element[type].all ?? [])
            .compactMap { node(using: $0, ofType: type) }
    }

    /// [RECURSIVE]
    /// Create a node(`Link`) from a <navPoint> element.
    /// If there is a nested element, recursively handle it.
    ///
    /// - Parameter element: The <navPoint> from the NCX Document.
    /// - Returns: The generated node(`Link`).
    private func node(using element: AEXMLElement, ofType type: String) -> Link? {
        guard let href = element["content"].attributes["src"] else {
            return nil
        }

        return Link(
            href: normalize(base: path, href: href),
            title: element["navLabel"]["text"].value,
            children: nodeArray(forNcxElement: element, ofType: type)
        )
    }
}
