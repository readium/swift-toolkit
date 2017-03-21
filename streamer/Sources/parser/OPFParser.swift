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
        parseMetadata(from: document, to: publication)
        parseSpineAndResources(from: document, to: publication)
        parseNavigationDocument(from: container, to: publication)
        parseNcxDocument(from: container, to: publication)
        return publication
    }

    /// Parse the Metadata in the XML <metadata> element.
    ///
    /// - Parameter document: Parse the Metadata in the XML <metadata> element.
    /// - Returns: The Metadata object representing the XML <metadata> element.
    internal func parseMetadata(from document: AEXMLDocument, to publication: Publication) {
        /// The 'to be returned' Metadata object.
        var metadata = Metadata()
        let mp = MetadataParser()
        let metadataElement = document.root["metadata"]

        metadata.title = mp.parseMainTitle(from: metadataElement, epubVersion: publication.epubVersion)
        metadata.identifier = mp.parseUniqueIdentifier(from: metadataElement,
                                                       withAttributes: document.root.attributes)
        // Description.
        if let description = metadataElement["dc:description"].value {
            metadata.description = description
        }

        // TODO: modified date.

        // TODO: subjects.

        // Languages.
        if let languages = metadataElement["dc:language"].all {
            metadata.languages = languages.map({ $0.string })
        }
        // Rights.
        if let rights = metadataElement["dc:rights"].all {
            metadata.rights = rights.map({ $0.string }).joined(separator: " ")
        }
        // Publishers, Creators, Contributors.
        mp.parseContributors(from: metadataElement, to: &metadata, with: publication.epubVersion)
        // Page progression direction.
        if let direction = document.root["spine"].attributes["page-progression-direction"] {
            metadata.direction = direction
        }
        // Rendition properties.
        mp.setRenditionProperties(from: metadataElement["meta"], to: &metadata)
        publication.metadata = metadata
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
            // Those links that were not in the spine are the resources have
            // already been removed from the `manifestLinks` dictionary.
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
            // The "to be built" link representing the manifest item.
            let link = Link()

            link.href = item.attributes["href"]
            link.typeLink = item.attributes["media-type"]
            // Look if item have any properties.
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

    /// Attempt to fill `Publication.tableOfContent`/`.landmarks`/`.pageList`/
    ///                              `.listOfIllustration`/`.listOftables`
    /// using the navigation document.
    ///
    /// - Parameters:
    ///   - container: The Epub container.
    ///   - publication: The Epub publication.
    internal func parseNavigationDocument(from container: Container, to publication: Publication) {
        let ndp = NavigationDocumentParser()

        // Get the link in the spine pointing to the Navigation Document.
        guard let navLink = publication.link(withRel: "contents"),
            let navDocument = try? container.xmlDocument(forRessourceReferencedByLink: navLink) else {
                return
        }
        let newTableOfContentsItems = ndp.tableOfContent(fromNavigationDocument: navDocument)
        let newPageListItems = ndp.pageList(fromNavigationDocument: navDocument)
        let newLandmarksItems = ndp.landmarks(fromNavigationDocument: navDocument)

        publication.tableOfContents.append(contentsOf:  newTableOfContentsItems)
        publication.pageList.append(contentsOf: newPageListItems)
        publication.landmarks.append(contentsOf: newLandmarksItems)
    }

    /// Attempt to fill `Publication.tableOfContent`/`.pageList` using the NCX 
    /// document. Will only modify the Publication if it has not be filled 
    /// previously (using the Navigation Document).
    ///
    /// - Parameters:
    ///   - container: The Epub container.
    ///   - publication: The Epub publication.
    internal func parseNcxDocument(from container: Container, to publication: Publication) {
        let ncxp = NCXParser()

        // Get the link in the spine pointing to the NCX document.
        guard let ncxLink = publication.resources.first(where: { $0.typeLink == "application/x-dtbncx+xml" }),
            let ncxDocument = try? container.xmlDocument(forRessourceReferencedByLink: ncxLink) else {
                return
        }
        if publication.tableOfContents.isEmpty {
            let newTableOfContentItems = ncxp.tableOfContents(fromNcxDocument: ncxDocument)

            publication.tableOfContents.append(contentsOf: newTableOfContentItems)
        }
        if publication.pageList.isEmpty {
            let newPageListItems = ncxp.pageList(fromNcxDocument: ncxDocument)

            publication.pageList.append(contentsOf: newPageListItems)
        }
    }
}
