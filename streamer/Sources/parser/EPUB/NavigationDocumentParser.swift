//
//  NavigationDocumentParser.swift
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
import Fuzi

/// The navigation document if documented here at Navigation
/// https://idpf.github.io/a11y-guidelines/
final public class NavigationDocumentParser {

    /// Return the data representation of the table of contents informations
    /// contained in the Navigation Document (toc).
    ///
    /// - Parameter document: The Navigation Document.
    /// - Returns: The data representation of the table of contents (toc).
    static internal func tableOfContent(fromNavigationDocument document: XMLDocument,
                                        locatedAt path: String) -> [Link] {
        var newTableOfContents = [Link]()
        
        document.definePrefix("html", defaultNamespace: "http://www.w3.org/1999/xhtml")
        
        let xpath = "/html:html/html:body/html:nav[@epub:type='toc']//html:a|"
            + "/html:html/html:body/html:nav[@epub:type='toc']//html:span"
        
        let elements = document.xpath(xpath)
        
        for element in elements {
            guard let href = element.attr("href") else {
                continue
            }
            newTableOfContents.append(Link(
                href: normalize(base: path, href: href),
                title: element.stringValue
            ))
        }
        
        return newTableOfContents
    }

    /// Return the data representation of the page-list informations
    /// contained in the Navigation Document.
    ///
    /// - Parameter document: The Navigation Document.
    /// - Returns: The data representation of the landmarks.
    static internal func pageList(fromNavigationDocument document: AEXMLDocument,
                                  locatedAt path: String) -> [Link] {
        let newPageList = nodeArray(forNavigationDocument: document,
                                    locatedAt: path, havingNavType: "page-list")

        return newPageList
    }

    /// Return the data representation of the landmarks informations
    /// contained in the Navigation Document.
    ///
    /// - Parameter document: The Navigation Document.
    /// - Returns: The data representation of the landmarks.
    static internal func landmarks(fromNavigationDocument document: AEXMLDocument,
                                   locatedAt path: String) -> [Link] {
        let newLandmarks = nodeArray(forNavigationDocument: document,
                                     locatedAt: path, havingNavType: "landmarks")

        return newLandmarks
    }

    /// Return the data representation of the list of illustrations informations
    /// contained in the Navigation Document (loi).
    ///
    /// - Parameter document: The Navigation Document.
    /// - Returns: The data representation of the list of illustrations (loi).
    static internal func listOfIllustrations(fromNavigationDocument document: AEXMLDocument,
                                             locatedAt path: String) -> [Link] {
        let newListOfIllustrations = nodeArray(forNavigationDocument: document,
                                               locatedAt: path, havingNavType: "loi")

        return newListOfIllustrations
    }

    /// Return the data representation of the list of tables informations
    /// contained in the Navigation Document (lot).
    ///
    /// - Parameter document: The Navigation Document.
    /// - Returns: The data representation of the list of illustrations (lot).
    static internal func listOfTables(fromNavigationDocument document: AEXMLDocument,
                                      locatedAt path: String) -> [Link] {
        let newListOfTables = nodeArray(forNavigationDocument: document,
                                        locatedAt: path, havingNavType: "lot")

        return newListOfTables
    }

    /// Return the data representation of the list of tables informations
    /// contained in the Navigation Document (lot).
    ///
    /// - Parameter document: The Navigation Document.
    /// - Returns: The data representation of the list of illustrations (lot).
    static internal func listOfAudiofiles(fromNavigationDocument document: AEXMLDocument,
                                          locatedAt path: String) -> [Link] {
        let newListOfAudiofiles = nodeArray(forNavigationDocument: document,
                                            locatedAt: path, havingNavType: "loa")

        return newListOfAudiofiles
    }

    /// Return the data representation of the list of tables informations
    /// contained in the Navigation Document (lot).
    ///
    /// - Parameter document: The Navigation Document.
    /// - Returns: The data representation of the list of illustrations (lot).
    static internal func listOfVideos(fromNavigationDocument document: AEXMLDocument,
                                      locatedAt path: String) -> [Link] {
        let newListOfVideos = nodeArray(forNavigationDocument: document,
                                        locatedAt: path, havingNavType: "lov")

        return newListOfVideos
    }

    // MARK: Fileprivate Methods.

    /// Generate an array of Link elements representing the XML structure of the
    /// navigation document. Each of them possibly having children.
    ///
    /// - Parameters:
    ///   - navigationDocument: The navigation document XML Object.
    ///   - navType: The navType of the items to fetch.
    ///              (eg "toc" for epub:type="toc").
    /// - Returns: The Object representation of the data contained in the
    ///            `navigationDocument` for the element of epub:type==`navType`.
    static fileprivate func nodeArray(forNavigationDocument document: AEXMLDocument,
                                      locatedAt path: String,
                                      havingNavType navType: String) -> [Link]
    {
        var body = document["nav"]["body"]["section"]
        if body.error == AEXMLError.elementNotFound {
            body = document["nav"]["body"]
        }
        // Retrieve the <nav> elements from the document with "epub:type"
        // property being equal to `navType`.
        // Then generate the nodeTree array from the <ol> nested in the <nav>,
        // if any.
        guard let navPoint = body["nav"].all?.first(where: { $0.attributes["epub:type"] == navType }),
            let olElement = navPoint["ol"].first else
        {
            return []
        }
        // Convert the XML element to a `Link` object. Recursive.
        return nodeArray(usingNavigationDocumentOl: olElement, path)
    }

    /// [RECURSIVE]
    /// Create a nodes list (`[Link]`) from a <ol> element, filling the nodes'
    /// children with nested <li> elements if any.
    /// If there are nested <ol> elements, recursively handle them.
    ///
    /// - Parameter element: The <ol> from the Navigation Document.
    /// - Returns: The generated nodes list.
    static fileprivate func nodeArray(usingNavigationDocumentOl element: AEXMLElement, _ navigationDocumentPath: String) -> [Link] {
        // Retrieve the children <li> elements of the <ol>.
        return (element["li"].all ?? [])
            .map { li in
                // FIXME: href is required for Link, but sometimes nested <ol> don't have any href. We need a proper Navigation tree structure instead of relying on `Link`.
                let link = Link(href: "#")
                
                let a = li["a"]
                if let href = a.attributes["href"] {
                    link.href = normalize(base: navigationDocumentPath, href: href)
                    link.title = a["span"].value ?? a.value
                } else {
                    link.title = li["span"].value
                }
                
                // If the <li> contains a nested <ol>, then we need to build the links recursively
                if let childOl = li["ol"].first {
                    link.children = nodeArray(usingNavigationDocumentOl: childOl, navigationDocumentPath)
                }
                
                return link
            }
    }

}
