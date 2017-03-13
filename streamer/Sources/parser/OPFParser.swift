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
    /// - Throws: `EpubParserError.missingFile`,
    ///           `EpubParserError.xmlParse`.
    internal func parseOPF(from container: inout Container) throws -> Publication {
        /// The 'to be built' Publication.
        let publication = Publication()
        /// Shortcuts to ContainerMetadata elements.
        ///     Relative path to the package.opf file.
        let rootFilePath = container.metadata.rootFilePath

        // Get the package.opf XML document from the container.
        let document = try getXmlDocumentForFile(in: container,
                                             atPath: rootFilePath)
        // Try to get EPUB version from the <package> element.
        // Else set it to default value.
        container.metadata.epubVersion = getEpubVersion(from: document)

        // TODO: Add self to links.
        // But we don't know the self URL here
        //publication.links.append(Link(href: "TODO", typeLink: "application/webpub+json", rel: "self"))

        // Parse Metadata from the XML document.
        let metadata = parseMetadata(from: document,
                                     with: container.metadata.epubVersion)
        // Look for the manifest item id of the cover.
        parseSpineAndResources(from: document, to: publication)
        //
        publication.metadata = metadata
        publication.internalData["type"] = "epub"
        publication.internalData["rootfile"] = rootFilePath
        return publication
    }

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
            let uniqueIdentifiers = identifiers.filter {
                $0.attributes["id"] == uniqueId
            }
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

    /// Parses the manifest and spine elements to build the document's spine and
    /// it resources list.
    ///
    /// - Parameters:
    ///   - document: The OPF XML document being parsed.
    ///   - publication: The publication whose spine and resources will be built.
    ///   - coverItemId: The id of the cover item in the manifest.
    internal func parseSpineAndResources(
        from document: AEXMLDocument,
        to publication: Publication) {
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
        parseManifestItems(from: manifest, to: publication,
                           and: &manifestLinks, with: coverId)
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

    /// Parses the differents manifest items from the XML <manifest> element.
    ///
    /// - Parameter manifest: The XML <manifest> element.
    internal func parseManifestItems(
        from manifest: AEXMLElement,
        to publication: Publication,
        and manifestLinks: inout [String: Link],
        with coverItemId: String?) {

        guard let manifestItems = manifest["item"].all else {
            return
        }
        // Create an Link for each item in the <manifest>
        for item in manifestItems {
            // Build a link for the manifest item
            let link = Link()

            link.href = item.attributes["href"]
            link.typeLink = item.attributes["media-type"]
            // Look for properties
            if let properties = item.attributes["properties"] {
                let ws = CharacterSet.whitespaces
                let propertiesArray = properties.components(separatedBy: ws)

                parseItemProperties(from: propertiesArray, to: link,
                                    and: publication)
            }
            // Add it to the manifest items dict if it has an id
            guard let id = item.attributes["id"] else {
                log(level: .error, "Manifest item has no \"id\" attribute")
                return
            }
            // If it's the cover's item id, set the rel to cover and add the
            // link to `links`
            if id == coverItemId {
                link.rel.append("cover")
                publication.links.append(link)
            }
            manifestLinks[id] = link
        }
    }

    // TODO: Refine description
    /// Parse the items misc properties (?).
    ///
    /// - Parameters:
    ///   - properties: The remaining properties array.
    ///   - link: The link which will be included into the Publication Object.
    ///   - publication: The concerned Publication.
    internal func parseItemProperties(
        from properties: [String],
        to link: Link,
        and publication: Publication) {

        let remainingProperties: [String]

        if properties.contains("nav") {
            link.rel.append("contents")
        }
        // If it's a cover, set the rel to cover and add the link to `links`
        if properties.contains("cover-image") {
            link.rel.append("cover")
            publication.links.append(link)
        }
        remainingProperties = properties.filter {
            $0 != "cover-image" && $0 != "nav"
        }
        link.properties.append(contentsOf: remainingProperties)
        // TODO: rendition properties
    }

    // MARK: - Private methods.

    /// Takes a Container and the path to one of it's ressource and returns an
    /// XML document.
    ///
    /// - Parameters:
    ///   - container: The Container containing the XML file.
    ///   - path: The path to the XML file.
    /// - Returns: The XML document Object generated.
    /// - Throws: EpubParserError.missingFile(),
    ///           EpubParserError.xmlParse().
    private func getXmlDocumentForFile(
        in container: Container,
        atPath path: String) throws -> AEXMLDocument {
        // The 'to be built' XML Document
        var document: AEXMLDocument

        // Get `Data` from the Container/OPFFile
        guard let data = try? container.data(relativePath: path) else {
            throw EpubParserError.missingFile(path: path)
        }
        // Transforms `Data` into an AEXML Document object
        do {
            document = try AEXMLDocument(xml: data)
        } catch {
            throw EpubParserError.xmlParse(underlyingError: error)
        }
        return document
    }

    /// Retrieve the EPUB version from the package.opf XML document.
    private func getEpubVersion(from document: AEXMLDocument) -> Double {
        let version: Double
        
        if let versionAttribute = document.root.attributes["version"],
            let versionNumber = Double(versionAttribute) {
            
            version = versionNumber
        } else {
            version = EpubConstant.defaultEpubVersion
        }
        return version
    }
    
}
