//
//  NavigationDocumentParser.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/17/17.
//  Copyright © 2017 Readium. All rights reserved.
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
            let link = Link()
            link.title = element.stringValue
            link.href = normalize(base: path, href: element.attr("href"))
            newTableOfContents.append(link)
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
        var nodeTree = Link()
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
        nodeTree = node(usingNavigationDocumentOl: olElement, path)

        return nodeTree.children
    }

    /// [RECURSIVE]
    /// Create a node(`Link`) from a <ol> element, filling the node
    /// children with nested <li> elements if any.
    /// If there are nested <ol> elements, recursively handle them.
    ///
    /// - Parameter element: The <ol> from the Navigation Document.
    /// - Returns: The generated node(`Link`).
    static fileprivate func node(usingNavigationDocumentOl element: AEXMLElement,
                                 _ navigationDocumentPath: String) -> Link {
        let newOlNode = Link()

        // Retrieve the children <li> elements of the <ol>.
        guard let liElements = element["li"].all else {
            return newOlNode
        }
        // For each <li>.
        for li in liElements {
            // Check if the <li> contains a <span> whom text value is not empty.
            if let spanText = li["span"].value, !spanText.isEmpty {
                // Retrieve the <ol> inside the <span> and do a recursive call.
                if let nextOl = li["ol"].first {
                    newOlNode.children.append(node(usingNavigationDocumentOl: nextOl, navigationDocumentPath))
                }
            } else {
                let childLiNode = node(usingNavigationDocumentLi: li, navigationDocumentPath)

                newOlNode.children.append(childLiNode)
            }
        }
        return newOlNode
    }

    /// [RECURSIVE]
    /// Create a node(`Link`) from a <li> element.
    /// If there is a nested <ol> element, recursively handle it.
    ///
    /// - Parameter element: The <ol> from the Navigation Document.
    /// - Returns: The generated node(`Link`).
    static fileprivate func node(usingNavigationDocumentLi element: AEXMLElement,
                                 _ navigationDocumentPath: String) -> Link {
        let newLiNode = Link ()
        var title = element["a"]["span"].value

        if title == nil {
            title = element["a"].value
        }
        newLiNode.href = normalize(base: navigationDocumentPath, href: element["a"].attributes["href"])
        newLiNode.title = title
        // If the <li> have a child <ol>.
        if let nextOl = element["ol"].first {
            // If a nested <ol> is found, insert it into the newNode childrens.
            newLiNode.children.append(node(usingNavigationDocumentOl: nextOl, navigationDocumentPath))
        }
        return newLiNode
    }
}
