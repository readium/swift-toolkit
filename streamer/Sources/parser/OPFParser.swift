//
//  OPFParser.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/21/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import AEXML

extension OPFParser: Loggable {}

/// EpubParser support class, able to parse the OPF package document.
/// OPF: Open Packaging Format.
public class OPFParser {

    // MARK: - Internal methods.

    internal init() {}

    /// Parse the OPF file of the Epub container and return a `Publication`.
    /// It also complete the informations stored in the container.
    ///
    /// - Parameter container: The EPUB container whom OPF file will be parsed.
    /// - Returns: The `Publication` object resulting from the parsing.
    /// - Throws: `EpubParserError.xmlParse`,
    ///           `OPFParserError.missingNavLink`,
    ///           `throw OPFParserError.missingNavLinkHref`.
    internal func parseOPF(from document: AEXMLDocument,
                           with container: Container,
                           and epubVersion: Double) throws -> Publication
    {
        /// The 'to be built' Publication.
        let publication = Publication()

        publication.epubVersion = epubVersion
        publication.internalData["type"] = "epub"
        publication.internalData["rootfile"] = container.rootFile.rootFilePath
        // TODO: Add self to links.
        // But we don't know the self URL here
        //publication.links.append(Link(href: "TODO", typeLink: "application/webpub+json", rel: "self"))
        publication.metadata = parseMetadata(from: document, with: epubVersion) // TODO format to: publiation
        parseSpineAndResources(from: document, to: publication)
        parseNavigationDocumentAndNcx(from: container, to: publication)
        return publication
    }

    /// Parses the manifest and spine elements to build the document's spine and
    /// its resources list.
    ///
    /// - Parameters:
    ///   - document: The OPF XML document being parsed.
    ///   - publication: The publication whose spine and resources will be built.
    ///   - coverItemId: The id of the cover item in the manifest.
    internal func parseSpineAndResources(from document: AEXMLDocument, to publication: Publication) {
        /// XML shortcuts
        let metadataElement = document.root["metadata"]
        let manifest = document.root["manifest"]
        // Create a dictionary for all the manifest items keyed by their id
        var manifestLinks = [String: Link]()
        var coverId: String?

        defer {
            // Those links that were not in the spine are the resources,
            // they've already been removed from the manifestLinks dictionary
            publication.resources = [Link](manifestLinks.values)
        }
        if let coverMetas = metadataElement["meta"].all(withAttributes: ["name" : "cover"]) {
            coverId = coverMetas.first?.string
        }
        guard let manifestItems = manifest["item"].all else {
            return
        }

        /// Parses the differents manifest items from the XML <manifest> element.
        /// Creates an Link for each item in the <manifest>.
        for item in manifestItems {
            // Build a link for the manifest item
            let link = Link()

            link.href = item.attributes["href"]
            link.typeLink = item.attributes["media-type"]
            // Look for properties
            if let propertyAttribute = item.attributes["properties"] {
                let ws = CharacterSet.whitespaces
                let properties = propertyAttribute.components(separatedBy: ws)

                if properties.contains("nav") {
                    link.rel.append("contents")
                }
                // If it's a cover, set the rel to cover and add the link to `links`
                if properties.contains("cover-image") {
                    link.rel.append("cover")
                    publication.links.append(link)
                }
                let otherProperties = properties.filter { $0 != "cover-image" && $0 != "nav" }
                link.properties.append(contentsOf: otherProperties)
                // TODO: rendition properties
            }
            // Add it to the manifest items dict if it has an id
            guard let id = item.attributes["id"] else {
                // Manifest item MUST have an id, ignore it
                log(level: .debug, "Manifest item has no \"id\" attribute.")
                continue
            }
            // If it's the cover's item id, set the rel to cover and add the
            // link to `links`
            if id == coverId {
                link.rel.append("cover")
                publication.links.append(link)
            }
            manifestLinks[id] = link
        }

        // Parse the `<spine>` element children
        guard let spineItems = document.root["spine"]["itemref"].all else {
            return
        }
        // For each spine item, look for the link in manifestLinks dictionary,
        // add it to the spine and remove it from manifestLinks.
        for item in spineItems {
            guard let id = item.attributes["idref"] else {
                continue
            }
            // Only linear items are added to the spine
            guard item.attributes["linear"]?.lowercased() != "no" else {
                continue
            }
            if let link = manifestLinks[id] {
                // Found the link in the manifest items, add it to the spine
                publication.spine.append(link)
                // Then remove it from the manifest
                manifestLinks.removeValue(forKey: id)
            }
        }
    }

    /// Attempt to fill `Publication.tableOfContent`/`.landmarks`/`.pageList`
    /// using the navigation document. If it cannot be found or access, try with
    /// the NCX document.
    /// NOTE: Navigation Document was introduced for Epub3+.
    ///
    /// - Parameters:
    ///   - container: The Epub container.
    ///   - publication: The Epub publication.
    internal func parseNavigationDocumentAndNcx(from container: Container,
                                                to publication: Publication)
    {
        // Get the link in the spine pointing to the Navigation Document.
        if var navLink = publication.spine.first(where: { $0.rel.contains("contents") }),
            let navDocument = try? container.xmlDocument(forRessourceReferencedByLink: navLink)
        {
            let newTableOfContentsItems = tableOfContent(fromNavigationDocument: navDocument)
            let newPageListItems = pageList(fromNavigationDocument: navDocument)
            let newLandmarksItems = landmarks(fromNavigationDocument: navDocument)

            publication.tableOfContents.append(contentsOf:  newTableOfContentsItems)
            publication.pageList.append(contentsOf: newPageListItems)
            publication.landmarks.append(contentsOf: newLandmarksItems)
        }
        // If the TOC has been filled using the Navigation Document, return.
        guard publication.tableOfContents.isEmpty else {
            return
        }
        // Else try to fill it using the NCX document.
        // Get the link in the spine pointing to the NCX document.
        if let ncxLink = publication.resources.first(where: { $0.typeLink == "application/x-dtbncx+xml" }),
            let ncxDocument = try? container.xmlDocument(forRessourceReferencedByLink: ncxLink)
        {
            let newTableOfContentItems = tableOfContents(fromNcxDocument: ncxDocument)
            //let newPageListItems = pageList(fromNavigationDocument: <#T##AEXMLDocument#>)

            publication.tableOfContents.append(contentsOf: newTableOfContentItems)
        }
        // TODO: fillPageListFromNCX(from: container, into: publication)
    }
}

// MARK: - Metadata Parsing.
extension OPFParser {

    /// Parse the Metadata in the XML <metadata> element.
    ///
    /// - Parameter document: Parse the Metadata in the XML <metadata> element.
    /// - Returns: The Metadata object representing the XML <metadata> element.
    internal func parseMetadata(from document: AEXMLDocument, with epubVersion: Double?) -> Metadata {
        /// The 'to be returned' Metadata object.
        var metadata = Metadata()
        let metadataElement = document.root["metadata"]
        let documentAttributes = document.root.attributes

        metadata.title = parseMainTitle(from: metadataElement, epubVersion: epubVersion)
        metadata.identifier = parseUniqueIdentifier(from: metadataElement,
                                                    withAttributes: documentAttributes)
        // Description
        if let description = metadataElement["dc:description"].value {
            metadata.description = description
        }

        // TODO: modified date

        // TODO: subjects

        // Languages
        if let languages = metadataElement["dc:language"].all {
            metadata.languages = languages.map { $0.string }
        }
        // Rights
        if let rights = metadataElement["dc:rights"].all {
            metadata.rights = rights.map({ $0.string }).joined(separator: " ")
        }
        // Publishers
        if let publishers = metadataElement["dc:publisher"].all {
            metadata.publishers.append(contentsOf:publishers.map({
                Contributor(name: $0.string)
            }))
        }
        // TODO: - Refactor pattern bellow.
        // Authors
        if let creators = metadataElement["dc:creator"].all {
            for creatorElement in creators {
                parseContributor(from: creatorElement,
                                 in: document,
                                 to: metadata,
                                 with: epubVersion)
            }
        }
        // Contributors
        if let contributors = metadataElement["dc:contributor"].all {
            for contributorElement in contributors {
                parseContributor(from: contributorElement,
                                 in: document,
                                 to: metadata,
                                 with: epubVersion)
            }
        }
        // Get the page progression direction.
        if let direction = document.root["spine"].attributes["page-progression-direction"] {
            metadata.direction = direction
        }
        // Rendition properties
        setRenditionProperties(from: metadataElement["meta"], to: &metadata)
        return metadata
    }

    /// Extracts the Rendition properties from the XML element metadata and fill
    /// then into the Metadata object instance.
    ///
    /// - Parameters:
    ///   - metadataElement: The XML element containing the metadatas.
    ///   - metadata: The `Metadata` object.
    internal func setRenditionProperties(from metadataElement: AEXMLElement,
                                         to metadata: inout Metadata) {
        // Layout
        var attribute = ["property" : "rendition:layout"]

        if let renditionLayouts = metadataElement.all(withAttributes: attribute),
            !renditionLayouts.isEmpty {
            let layouts = renditionLayouts[0].string

            metadata.rendition.layout = RenditionLayout(rawValue: layouts)
        }
        // Flow
        attribute = ["property" : "rendition:flow"]
        if let renditionFlows = metadataElement.all(withAttributes: attribute),
            !renditionFlows.isEmpty {
            let flows = renditionFlows[0].string

            metadata.rendition.flow = RenditionFlow(rawValue: flows)
        }
        // Orientation
        attribute = ["property" : "rendition:orientation"]
        if let renditionOrientations = metadataElement.all(withAttributes: attribute),
            !renditionOrientations.isEmpty {
            let orientation = renditionOrientations[0].string

            metadata.rendition.orientation = RenditionOrientation(rawValue: orientation)
        }
        // Spread
        attribute = ["property" : "rendition:spread"]
        if let renditionSpreads = metadataElement.all(withAttributes: attribute),
            !renditionSpreads.isEmpty {
            let spread = renditionSpreads[0].string

            metadata.rendition.spread = RenditionSpread(rawValue: spread)
        }
        // Viewport
        attribute = ["property" : "rendition:viewport"]
        if let renditionViewports = metadataElement.all(withAttributes: attribute),
            !renditionViewports.isEmpty {
            metadata.rendition.viewport = renditionViewports[0].string
        }
    }

    /// Get the main title of the publication from the from the OPF XML document
    /// `<metadata>` element.
    ///
    /// - Parameter metadata: The `<metadata>` element.
    /// - Returns: The content of the `<dc:title>` element, `nil` if the element
    ///            wasn't found.
    internal func parseMainTitle(from metadata: AEXMLElement, epubVersion: Double?) -> String? {
        // Return if there isn't any `<dc:title>` element
        guard let titles = metadata["dc:title"].all else {
            return nil
        }
        // If there's more than one, look for the `main` one as defined by
        // `refines`.
        // Else, as a fallback and default, return the first `<dc:title>`
        // content.
        guard titles.count > 1, epubVersion == 3 else {
            return metadata["dc:title"].string
        }
        /// Used in the closure below.
        func isMainTitle(element: AEXMLElement) -> Bool {
            guard let eid = element.attributes["id"] else {
                return false
            }
            let attributes = ["property": "title-type", "refines": "#" + eid]
            let metas = metadata["meta"].all(withAttributes: attributes)

            return metas?.contains(where: { $0.string == "main" }) ?? false
        }
        // Returns the first main title encountered
        return titles.first(where: { isMainTitle(element: $0)})?.string
    }

    /// Get the unique identifer of the publication from the from the OPF XML
    /// document `<metadata>` element.
    ///
    /// - Parameters:
    ///   - metadata: The `<metadata>` element.
    ///   - Attributes: The XML document attributes.
    /// - Returns: The content of the `<dc:identifier>` element, `nil` if the
    ///             element wasn't found.
    internal func parseUniqueIdentifier(from metadata: AEXMLElement,
                                        withAttributes attributes: [String : String]) -> String? {
        // Look for `<dc:identifier>` elements
        guard let identifiers = metadata["dc:identifier"].all else {
            return nil
        }
        // Get the one defined as unique by the `<package>` attribute
        // `unique-identifier`
        if identifiers.count > 1,
            let uniqueId = attributes["unique-identifier"] {
            let uniqueIdentifiers = identifiers.filter { $0.attributes["id"] == uniqueId }
            if !uniqueIdentifiers.isEmpty, let uid = uniqueIdentifiers.first {
                return uid.string
            }
        }
        // Returns the first `<dc:identifier>` content or an empty String
        return metadata["dc:identifier"].string
    }

    /// Builds a `Contributor` instance from a `<dc:creator>` or
    /// `<dc:contributor>` element.
    ///
    /// - Parameters:
    ///   - element: The XML element to parse.
    ///   - doc: The OPF XML document being parsed (necessary to look for
    ///          `refines`).
    /// - Returns: The contributor instance filled with its name and optionally
    ///            its `role` and `sortAs` attributes.
    internal func createContributor(from element: AEXMLElement, metadata: AEXMLElement,
                                    epubVersion: Double?) -> Contributor {
        // The 'to be returned' Contributor object.
        let contributor = Contributor(name: element.string)

        // Get role from role attribute
        if let role = element.attributes["opf:role"] {
            contributor.role = role
        }
        // Get sort name from file-as attribute
        if let sortAs = element.attributes["opf:file-as"] {
            contributor.sortAs = sortAs
        }
        // Look up for possible meta refines for role
        if epubVersion == 3, let eid = element.attributes["id"] {
            let attributes = ["property": "role", "refines": "#\(eid)"]

            if let metas = metadata["meta"].all(withAttributes: attributes),
                !metas.isEmpty, let first = metas.first {
                let role = first.string

                contributor.role = role
            }
        }
        return contributor
    }

    /// Parse a `creator` or `contributor` element from the OPF XML document,
    /// then builds and adds a Contributor to the metadata, to an array
    /// according to its role (authors, translators, etc.).
    ///
    /// - Parameters:
    ///   - element: The XML element to parse.
    ///   - doc: The OPF XML document being parsed.
    ///   - metadata: The metadata to which to add the contributor.
    internal func parseContributor(from element: AEXMLElement,
                                   in document: AEXMLDocument,
                                   to metadata: Metadata,
                                   with epubVersion: Double?) {
        let metadataElement = document.root["metadata"]
        let contributor = createContributor(from: element,
                                            metadata: metadataElement,
                                            epubVersion: epubVersion)

        // Add the contributor to the proper property according to the its `role`
        if let role = contributor.role {
            switch role {
            case "aut":
                metadata.authors.append(contributor)
            case "trl":
                metadata.translators.append(contributor)
            case "art":
                metadata.artists.append(contributor)
            case "edt":
                metadata.editors.append(contributor)
            case "ill":
                metadata.illustrators.append(contributor)
            case "clr":
                metadata.colorists.append(contributor)
            case "nrt":
                metadata.narrators.append(contributor)
            case "pbl":
                metadata.publishers.append(contributor)
            default:
                metadata.contributors.append(contributor)
            }
        } else {
            // No role, so add the creators to the authors and the others to the contributors
            if element.name == "dc:creator" {
                metadata.authors.append(contributor)
            } else {
                metadata.contributors.append(contributor)
            }
        }
    }
}

// MARK: - Navigation Document Parsing
extension OPFParser {

    /// [SUGAR]
    /// Return the data representation of the toc informations
    /// contained in the Navigation Document.
    ///
    /// - Parameter document: The Navigation Document.
    /// - Returns: The data representation of the toc.
    internal func tableOfContent(fromNavigationDocument document: AEXMLDocument) -> [Link] {
        let newTableOfContents = nodeArray(forNavigationDocument: document, havingNavType: "toc")

        return newTableOfContents
    }

    /// [SUGAR]
    /// Return the data representation of the page-list informations
    /// contained in the Navigation Document.
    ///
    /// - Parameter document: The Navigation Document.
    /// - Returns: The data representation of the landmarks.
    internal func pageList(fromNavigationDocument document: AEXMLDocument) -> [Link] {
        let newPageList = nodeArray(forNavigationDocument: document, havingNavType: "page-list")

        return newPageList
    }

    /// [SUGAR]
    /// Return the data representation of the landmarks informations
    /// contained in the Navigation Document.
    ///
    /// - Parameter document: The Navigation Document.
    /// - Returns: The data representation of the landmarks.
    internal func landmarks(fromNavigationDocument document: AEXMLDocument) -> [Link] {
        let newLandmarks = nodeArray(forNavigationDocument: document, havingNavType: "landmarks")

        return newLandmarks
    }

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
        let section = document.root["body"]["section"]

        // Retrieve the <nav> elements from the document with "epub:type"
        // property being equal to `navType`.
        // Then generate the nodeTree array from the <ol> nested in the <nav>, 
        // if any.
        guard let navPoint = section["nav"].all?.first(where: { $0.attributes["epub:type"] == navType }),
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

        newLiNode.href = element["a"].attributes["href"]
        newLiNode.title = element["a"]["span"].value
        // If the <li> have a child <ol>.
        if let nextOl = element["ol"].first {
            // If a nested <ol> is found, insert it into the newNode childrens.
            newLiNode.children.append(node(usingNavigationDocumentOl: nextOl))
        }
        return newLiNode
    }
}

// MARK: - NCX Parsing
/// The NCX is been replaced but the Navigation Document in Epub3.
extension OPFParser {

    /// [SUGAR]
    /// Return the data representation of the toc informations contained in the
    /// NCX Document.
    ///
    /// - Parameter document: The NCX Document.
    /// - Returns: The data representation of the toc.
    fileprivate func tableOfContents(fromNcxDocument document: AEXMLDocument) -> [Link] {
        let tableOfContentsNodes = nodeArray(forNcxDocument: document)

        return tableOfContentsNodes
    }

    /// Generate an array of Link elements representing the XML structure of the
    /// NCX document. Each of them possibly having children.
    ///
    /// - Parameters:
    ///   - ncxDocument: The NCX document XML Object.
    /// - Returns: The Object representation of the data contained in the
    ///            `ncxDocument` XML.
    fileprivate func nodeArray(forNcxDocument document : AEXMLDocument) -> [Link] {
        let navMap = document.root["navMap"]
        var newNodeArray = [Link]()

        guard let navPoints = navMap["navPoint"].all else {
            return []
        }
        // For each navPoint found, add them with their children to the TOC.
        for navPoint in navPoints {
            let newNode = node(usingNavPoint: navPoint)

            newNodeArray.append(newNode)
        }
        return newNodeArray
    }

    /// [RECURSIVE]
    /// Create a node(`Link`) from a <navPoint> element.
    /// If there is a nested <navPoint> element, recursively handle it.
    ///
    /// - Parameter element: The <navPoint> from the NCX Document.
    /// - Returns: The generated node(`Link`).
    fileprivate func node(usingNavPoint element: AEXMLElement) -> Link {
        var newNode = Link()

        // Get current node informations.
        newNode.href = element["content"].attributes["src"]
        newNode.title = element["navLabel"]["text"].value
        // Retrieve the children of the current node.
        if let childrenNodes = element["navPoint"].all {
            // Add current node children recursively.
            for childNode in childrenNodes {
                newNode.children.append(node(usingNavPoint: childNode))
            }
        }
        return newNode
    }
}

