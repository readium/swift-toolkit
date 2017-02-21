//
//  RDEpubParser.swift
//  R2Streamer
//
//  Created by Olivier Körner on 08/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation
import AEXML

/// Errors thrown during the parsing of the EPUB
///
/// - wrongMimeType: The mimetype file is missing or its content differs from
///                 `application/epub+zip`.
/// - missingFile: A file is missing from the container.
/// - xmlParse: An XML parsing error occurred.
/// - missingElement: An XML element is missing.
public enum EpubParserError: Error {

    /// MimeType is not my
    case wrongMimeType

    /// A file is missing from the container at relative path **path**.
    case missingFile(path: String)

    /// An XML parsing error occurred, **underlyingError** thrown by the parser.
    case xmlParse(underlyingError: Error)

    case missingElement(message: String)
}

/// An EPUB container parser that extracts the information from the relevant
/// files and builds a `Publication` instance with it.
///
/// - It checks for a `mimetype` file with the proper contents.
/// - It parses `container.xml` to look for the default rendition.
/// - It parses the OPF file of the default rendition for the metadata,
///   the assets and the spine.
open class EpubParser {

    /// The EPUB container to parse.
    var container: EpubDataContainer

    /// The path to the default package document (OPF) to parse.
    var rootFile: String?

    // FIXME: This is a parsing class, and the data shoudln't be stored here?
    //       The functions returns/take as parameter the publication so i guess we
    //       can get ride of the member variable
    //    /// The publication resulting from the parsing, if it is successful.
    //    var publication: Publication?

    /// The EPUB specification version to which the publication conforms.
    var epubVersion: Int?

    // TODO: multiple renditions
    // TODO: media overlays
    // TODO: TOC, LOI, etc.
    // TODO: encryption info

    // MARK: - Public/Open methods

    /// The `RDEpubParser` is initialized with a `Container`, through which it
    /// can access to the files in the EPUB container.
    ///
    /// - Parameter container: a `Container` instance.
    public init(container: EpubDataContainer) {
        self.container = container
        // FIXME: Could we parse the container here so that we don't deal with
        //          rootFile being optional afterward? see parseOPF()
    }

    /// Parses the EPUB container files and builds a `Publication` representation.
    ///
    /// - Returns: the resulting publication or nil.
    /// - Throws: `EpubParserError.wrongMimeType`, `EpubParserError.xmlParse`,
    ///           `EpubParserError.missingFile`
    public func parse() throws -> Publication? {
        guard isMimeTypeValid() else {
            throw EpubParserError.wrongMimeType
        }
        try parseContainer()
        let publication = try parseOPF(at: rootFile!)
        return publication
    }

    /// Parses the container.xml file of the container.
    /// It extracts the root file (the default one for now, not handling
    /// multiple renditions)
    ///
    /// - Throws: `EpubParserError.xmlParse`, `EpubParserError.missingFile`
    public func parseContainer() throws {
        let containerPath = "META-INF/container.xml"

        guard let containerData = try? container.data(relativePath: containerPath) else {
            throw EpubParserError.missingFile(path: containerPath)
        }

        let containerXml: AEXMLDocument
        // FIXME when a guard ... catch is implemented
        // or simply don't rethrow ou own error and let the AEXML error flow?
        // I guess it would be better. If we don't catch it it will just rethrow
        do {
            containerXml = try AEXMLDocument(xml: containerData)
        }
        catch {
            throw EpubParserError.xmlParse(underlyingError: error)
        }

        // Look for the first `<roofile>` element
        let rootFileElement = containerXml.root["rootfiles"]["rootfile"]

        guard let fullPath = rootFileElement.attributes["full-path"] else {
            throw EpubParserError.missingElement(message: "Missing rootfile element in container.xml")
        }
        rootFile = fullPath

        // Get the specifications version the EPUB conforms to
        // If not set in the container, it will be retrieved in the OPF
        if let version = rootFileElement.attributes["version"] {
            epubVersion = Int(version)
        }
    }

    /// Parses an OPF package document in the container.
    ///
    /// - Parameter path: The relative path to OPF package file
    /// - Returns: The optional publication resulting from the parsing.
    /// - Throws: `EpubParserError.xmlParse`, `EpubParserError.missingFile`
    public func parseOPF(at path: String) throws -> Publication? {
        let publication = Publication()
        let metadata: Metadata

        // Get OPF document data from the container
        // FIXME: make rootFile non optional
        guard let data = try? container.data(relativePath: rootFile!) else {
            throw EpubParserError.missingFile(path: rootFile!)
        }

        // Create an XML document from the data
        let document: AEXMLDocument
        // FIXME: same as in the parseContainer function
        do {
            document = try AEXMLDocument(xml: data)
        } catch {
            throw EpubParserError.xmlParse(underlyingError: error)
        }

        // FIXME: we are not sure to retrieve it, again. Is that ok?
        // Try to get EPUB version from the <package> element if it was not set in
        // the container
        if epubVersion == nil, let version = document.root.attributes["version"] {
            epubVersion = Int(version)
        }
        publication.internalData["type"] = "epub"
        publication.internalData["rootfile"] = rootFile

        // Add self to links
        // MARK: we don't know the self URL here
        //publication!.links.append(Link(href: "TODO", typeLink: "application/webpub+json", rel: "self"))

        metadata = parseMetadata(from: document) //HERE1

        // Get the page progression direction
        if let dir = document.root["spine"].attributes["page-progression-direction"] {
            metadata.direction = dir
        }

        publication.metadata = metadata

        // Look for the manifest item id of the cover
        var coverId: String?
        let metadataElement = document.root["metadata"]

        if let coverMetas = metadataElement["meta"].all(withAttributes: ["name" : "cover"]) {
            coverId = coverMetas.first?.string
        }

        parseSpineAndResources(fromDocument: document, toPublication: publication, coverItemId: coverId)

        return publication
    }

    // MARK: - Private methods

    /// Checks if the mimetype file is present and contains `application/epub+zip`.
    ///
    /// - Returns: boolean result of the check
    private func isMimeTypeValid() -> Bool {
        guard let mimeTypeData = try? container.data(relativePath: "mimetype") else {
            return false
        }
        let mimetype = String(data: mimeTypeData, encoding: .ascii)

        return (mimetype == "application/epub+zip")
    }

    /// Parse the Metadata in the XML <metadata> element
    ///
    /// - Parameter document: Parse the Metadata in the XML <metadata> element
    /// - Returns: The Metadata object representing the XML <metadata> element
    private func parseMetadata(from document: AEXMLDocument) -> Metadata {
        let metadata = Metadata()
        let metadataElement = document.root["metadata"]
        let documentAttributes = document.root.attributes

        metadata.title = parseMainTitle(from: metadataElement)
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
            metadata.languages = languages.map { return $0.string }
        }

        // Rights
        if let rights = metadataElement["dc:rights"].all {
            metadata.rights = rights.map({ return $0.string }).joined(separator: " ")
        }

        // Publishers
        if let publishers = metadataElement["dc:publisher"].all {
            for publisher in publishers {
                metadata.publishers.append(Contributor(name: publisher.string))
            }
        }

        // Authors
        if let creators = metadataElement["dc:creator"].all {
            for creatorElement in creators {
                parseContributor(from: creatorElement, in: document, to: metadata)
            }
        }

        // Contributors
        if let contributors = metadataElement["dc:contributor"].all {
            for contributorElement in contributors {
                parseContributor(from: contributorElement, in: document, to: metadata)
            }
        }

        // Rendition properties
        if let renditionLayouts = metadataElement["meta"].all(withAttributes: ["property" : "rendition:layout"]) {
            if !renditionLayouts.isEmpty {
                metadata.rendition.layout = RenditionLayout(rawValue: renditionLayouts[0].string)
            }
        }
        if let renditionFlows = metadataElement["meta"].all(withAttributes: ["property" : "rendition:flow"]) {
            if !renditionFlows.isEmpty {
                metadata.rendition.flow = RenditionFlow(rawValue: renditionFlows[0].string)
            }
        }
        if let renditionOrientations = metadataElement["meta"].all(withAttributes: ["property" : "rendition:orientation"]) {
            if !renditionOrientations.isEmpty {
                metadata.rendition.orientation = RenditionOrientation(rawValue: renditionOrientations[0].string)
            }
        }
        if let renditionSpreads = metadataElement["meta"].all(withAttributes: ["property" : "rendition:spread"]) {
            if !renditionSpreads.isEmpty {
                metadata.rendition.spread = RenditionSpread(rawValue: renditionSpreads[0].string)
            }
        }
        if let renditionViewports = metadataElement["meta"].all(withAttributes: ["property" : "rendition:viewport"]) {
            if !renditionViewports.isEmpty {
                metadata.rendition.viewport = renditionViewports[0].string
            }
        }
        return metadata
    }

    /// Get the main title of the publication from the from the OPF XML document
    /// `<metadata>` element
    ///
    /// - Parameter metadata: The `<metadata>` element
    /// - Returns: The content of the `<dc:title>` element, `nil` if the element
    ///             wasn't found
    private func parseMainTitle(from metadata: AEXMLElement) -> String? {
        // Return if there isn't any `<dc:title>` element
        guard let titles = metadata["dc:title"].all else {
            return nil
        }

        // TODO: refactor this
        // If there's more than one, look for the `main` one as defined by `refines`
        if titles.count > 1 && epubVersion == 3 {
            let mainTitles = titles.filter { (element: AEXMLElement) in
                guard let eid = element.attributes["id"] else {
                    return false
                }
                let metas = metadata["meta"].all(withAttributes: ["property": "title-type", "refines": "#" + eid])
                if let mainMetas = metas?.filter({ $0.string == "main" }) {
                    return !mainMetas.isEmpty
                }
                return false
            }
            if !mainTitles.isEmpty {
                return mainTitles.first!.string
            }
        }

        // As a fallback and default, return the first `<dc:title>` content
        return metadata["dc:title"].string
    }

    /// Get the unique identifer of the publication from the from the OPF XML
    /// document `<metadata>` element
    ///
    /// - Parameters:
    ///   - metadata: The `<metadata>` element
    ///   - Attributes: The XML document attributes
    /// - Returns: The content of the `<dc:identifier>` element, `nil` if the
    ///             element wasn't found
    private func parseUniqueIdentifier(from metadata: AEXMLElement,
                                       withAttributes attributes: [String : String]) -> String? {
        // Look for `<dc:identifier>` elements
        guard let identifiers = metadata["dc:identifier"].all else {
            return nil
        }
        // Get the one defined as unique by the `<package>` attribute
        // `unique-identifier`
        if identifiers.count > 1, let uniqueId = attributes["unique-identifier"] {
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
    ///   - doc: The OPF XML document being parsed (necessary to look for `refines`).
    /// - Returns: The contributor instance filled with its name and optionally
    ///            its `role` and `sortAs` attributes.
    func createContributor(from element: AEXMLElement, metadata: AEXMLElement) -> Contributor {
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
    /// according to its role (authors, translators, etc.)
    ///
    /// - Parameters:
    ///   - element: The XML element to parse
    ///   - doc: The OPF XML document being parsed
    ///   - metadata: The metadata to which to add the contributor
    func parseContributor(from element: AEXMLElement, in document: AEXMLDocument,
                          to metadata: Metadata) {
        let metadataElement = document.root["metadata"]
        let contributor = createContributor(from: element, metadata: metadataElement)

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
    ///   - doc: The OPF XML document being parsed.
    ///   - publication: The publication whose spine and resources will be built.
    ///   - coverItemId: The id of the cover item in the manifest.
    func parseSpineAndResources(fromDocument doc: AEXMLDocument, toPublication publication: Publication, coverItemId: String?) {
        // Create a dictionary for all the manifest items keyed by their id
        var manifestLinks = [String: Link]()

        // Find all the manifest items
        if let manifestItems = doc.root["manifest"]["item"].all {

            // Create an Link for each of them
            for item in manifestItems {

                // Build a link for the manifest item
                let link = Link()
                link.href = item.attributes["href"]
                link.typeLink = item.attributes["media-type"]

                // Look for properties
                if let propAttr = item.attributes["properties"] {
                    let props = propAttr.components(separatedBy: CharacterSet.whitespaces)

                    if props.contains("nav") {
                        link.rel.append("contents")
                    }

                    // If it's a cover, set the rel to cover and add the link to `links`
                    if props.contains("cover-image") {
                        link.rel.append("cover")
                        publication.links.append(link)
                    }

                    let otherProps = props.filter({ (prop) -> Bool in
                        return (prop != "nav" && prop != "cover-image")
                    })
                    link.properties.append(contentsOf: otherProps)

                    // TODO: rendition properties
                }

                // Add it to the manifest items dict if it has an id
                if let id = item.attributes["id"] {

                    // If it's the cover's item id, set the rel to cover and add the link to `links`
                    if id == coverItemId {
                        link.rel.append("cover")
                        publication.links.append(link)
                    }

                    manifestLinks[id] = link
                } else {
                    // Manifest item MUST have an id, ignore it
                    NSLog("Manifest item has no \"id\" attribute")
                }
            }
        }

        // Parse the `<spine>` element children
        if let spineItems = doc.root["spine"]["itemref"].all {

            // For each spine item, look for the link in manifestLinks dictionary,
            // add it to the spine and remove it from manifestLinks.
            for item in spineItems {
                if let id = item.attributes["idref"] {

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
        }
        
        // Those links that were not in the spine are the resources,
        // they've already been removed from the manifestLinks dictionary
        publication.resources = [Link](manifestLinks.values)
    }
    
}
