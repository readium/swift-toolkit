//
//  NavigationDocumentParser.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/17/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import AEXML

/// The navigation document if documented here at Navigation
/// https://idpf.github.io/a11y-guidelines/
public class NavigationDocumentParser {

    /// [SUGAR] on top of nodeArray.
    /// Return the data representation of the table of contents informations
    /// contained in the Navigation Document (toc).
    ///
    /// - Parameter document: The Navigation Document.
    /// - Returns: The data representation of the table of contents (toc).
    internal func tableOfContent(fromNavigationDocument document: AEXMLDocument) -> [Link] {
        let newTableOfContents = nodeArray(forNavigationDocument: document, havingNavType: "toc")

        return newTableOfContents
    }

    /// [SUGAR] on top of nodeArray.
    /// Return the data representation of the page-list informations
    /// contained in the Navigation Document.
    ///
    /// - Parameter document: The Navigation Document.
    /// - Returns: The data representation of the landmarks.
    internal func pageList(fromNavigationDocument document: AEXMLDocument) -> [Link] {
        let newPageList = nodeArray(forNavigationDocument: document, havingNavType: "page-list")

        return newPageList
    }

    /// [SUGAR] on top of nodeArray.
    /// Return the data representation of the landmarks informations
    /// contained in the Navigation Document.
    ///
    /// - Parameter document: The Navigation Document.
    /// - Returns: The data representation of the landmarks.
    internal func landmarks(fromNavigationDocument document: AEXMLDocument) -> [Link] {
        let newLandmarks = nodeArray(forNavigationDocument: document, havingNavType: "landmarks")

        return newLandmarks
    }

    /// [SUGAR] on top of nodeArray.
    /// Return the data representation of the list of illustrations informations
    /// contained in the Navigation Document (loi).
    ///
    /// - Parameter document: The Navigation Document.
    /// - Returns: The data representation of the list of illustrations (loi).
    internal func listOfIllustrations(fromNavigationDocument document: AEXMLDocument) -> [Link] {
        let newListOfIllustrations = nodeArray(forNavigationDocument: document, havingNavType: "loi")

        return newListOfIllustrations
    }

    /// [SUGAR] on top of nodeArray.
    /// Return the data representation of the list of tables informations
    /// contained in the Navigation Document (lot).
    ///
    /// - Parameter document: The Navigation Document.
    /// - Returns: The data representation of the list of illustrations (lot).
    internal func listOfTables(fromNavigation document: AEXMLDocument) -> [Link] {
        let newListOfTables = nodeArray(forNavigationDocument: document, havingNavType: "lot")

        return newListOfTables
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
    fileprivate func nodeArray(forNavigationDocument document: AEXMLDocument,
                               havingNavType navType: String) -> [Link]
    {
        var nodeTree = Link()
        var body = document.root["body"]["section"]

        if body.error == AEXMLError.elementNotFound {
            body = document.root["body"]
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
        nodeTree = node(usingNavigationDocumentOl: olElement)

        return nodeTree.children
    }

    /// [RECURSIVE]
    /// Create a node(`Link`) from a <ol> element, filling the node
    /// children with nested <li> elements if any.
    /// If there are nested <ol> elements, recursively handle them.
    ///
    /// - Parameter element: The <ol> from the Navigation Document.
    /// - Returns: The generated node(`Link`).
    fileprivate func node(usingNavigationDocumentOl element: AEXMLElement) -> Link {
        var newOlNode = Link()

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
                    newOlNode.children.append(node(usingNavigationDocumentOl: nextOl))
                }
            } else {
                let childLiNode = node(usingNavigationDocumentLi: li)

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
    fileprivate func node(usingNavigationDocumentLi element: AEXMLElement) -> Link {
        var newLiNode = Link ()
        var title = element["a"]["span"].value

        if title == nil {
            title = element["a"].value
        }
        newLiNode.href = element["a"].attributes["href"]
        newLiNode.title = title
        // If the <li> have a child <ol>.
        if let nextOl = element["ol"].first {
            // If a nested <ol> is found, insert it into the newNode childrens.
            newLiNode.children.append(node(usingNavigationDocumentOl: nextOl))
        }
        return newLiNode
    }
}
