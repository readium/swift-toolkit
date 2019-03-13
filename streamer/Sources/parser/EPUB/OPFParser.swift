//
//  OPFParser.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri on 2/21/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import R2Shared
import AEXML

// http://www.idpf.org/epub/30/spec/epub30-publications.html#elemdef-opf-dctitle
// the six basic values of the "title-type" property specified by EPUB 3:
public enum EPUBTitleType: String {
    case main
    case subtitle
    case short
    case collection
    case edition
    case extended
}

extension OPFParser: Loggable {}

public enum OPFParserError: Error {
    /// The Epub have no title. Title is mandatory.
    case missingPublicationTitle
    case invalidSmilResource
    
    var localizedDescription: String {
        switch self {
        case .missingPublicationTitle:
            return "The publication is missing a title."
        case .invalidSmilResource:
            return "Smile resource couldn't beparsed."
        }
    }
}

/// EpubParser support class, able to parse the OPF package document.
/// OPF: Open Packaging Format.
final public class OPFParser {
    /// Parse the OPF file of the Epub container and return a `Publication`.
    /// It also complete the informations stored in the container.
    ///
    /// - Parameter container: The EPUB container whom OPF file will be parsed.
    /// - Returns: The `Publication` object resulting from the parsing.
    /// - Throws: `EpubParserError.xmlParse`.
    static internal func parseOPF(from document: AEXMLDocument,
                                  with rootFilePath: String,
                                  and epubVersion: Double) throws -> Publication
    {
        /// The 'to be built' Publication.
        var publication = Publication()
        publication.version = epubVersion
        publication.internalData["type"] = "epub"
        publication.internalData["rootfile"] = rootFilePath
        try parseMetadata(from: document, to: &publication)
        parseResources(from: document["package"]["manifest"], metadata: document["package"]["metadata"], to: &publication, rootFilePath)
        parseReadingOrder(from: document["package"], to: &publication)
        return publication
    }

    /// Parse the Metadata in the XML <metadata> element.
    ///
    /// - Parameter document: Parse the Metadata in the XML <metadata> element.
    /// - Returns: The Metadata object representing the XML <metadata> element.
    static internal func parseMetadata(from document: AEXMLDocument, to publication: inout Publication) throws {
        /// The 'to be returned' Metadata object.
        var metadata = Metadata()
        let metadataElement = document["package"]["metadata"]
        
        // Title.
        guard let multilangTitle = MetadataParser.mainTitle(from: metadataElement) else {
            throw OPFParserError.missingPublicationTitle
        }
        metadata.multilangTitle = multilangTitle
        
        // Subtitle.
        let multilangSubtitle = MetadataParser.subTitle(from: metadataElement)
        metadata.multilangSubtitle = multilangSubtitle
        
        // Identifier.
        metadata.identifier = MetadataParser.uniqueIdentifier(from: metadataElement,
                                                              with: document["package"].attributes)
        // Description.
        if let description = metadataElement["dc:description"].value {
            metadata.description = description
        }
        // From the EPUB 2 and EPUB 3 specifications, only the `dc:date` element without any attribtes will be considered for the `published` property.
        // And only the string with full date will be considered as valid date string. The string format validation happens in the `setter` of `published`.
        if let dateString = metadataElement["dc:date"].all?.filter({ (thisElement) -> Bool in
            return thisElement.attributes.count == 0
        }).first?.value {
            metadata.published = dateString.dateFromISO8601
        }
        // Last modification date.
        metadata.modified = MetadataParser.modifiedDate(from: metadataElement)
        // Source.
        if let source = metadataElement["dc:source"].value {
            metadata.otherMetadata["source"] = source
        }
        // Subject.
        if let subject = MetadataParser.subject(from: metadataElement) {
            metadata.subjects.append(subject)
        }
        // Languages.
        if let languages = metadataElement["dc:language"].all {
            metadata.languages = languages.map({ $0.string })
        }
        // Rights.
        if let rights = metadataElement["dc:rights"].all {
            metadata.otherMetadata["rights"] = rights.map({ $0.string }).joined(separator: " ")
        }
        // Publishers, Creators, Contributors.
        let epubVersion = publication.version
        MetadataParser.parseContributors(from: metadataElement, to: &metadata, epubVersion)
        // Page progression direction.
        
        if let pageProgressionDirection = document["package"]["readingOrder"].attributes["page-progression-direction"] ?? document["package"]["spine"].attributes["page-progression-direction"] {
            metadata.readingProgression = {
                switch pageProgressionDirection {
                case "ltr":
                    return .ltr
                case "rtl":
                    return .rtl
                case "default":
                    return .auto
                default:
                    return .auto
                }
            }()
        }

        // Rendition properties.
        MetadataParser.parseRenditionProperties(from: metadataElement, to: &metadata)
        publication.metadata = metadata
        /// Other Metadata.
        // Media overlays: media:duration
        MetadataParser.parseMediaDurations(from: metadataElement, to: &metadata.otherMetadata)
    }

    /// Parse XML elements of the <Manifest> in the package.opf file.
    ///
    /// - Parameters:
    ///   - manifest: The Manifest XML element.
    ///   - metadata: The metadata XML element.
    ///   - publication: The `Publication` object with `.resource` properties to
    ///                  fill.
    ///   - coverId: The coverId to identify the cover ressource and tag it.
    static internal func parseResources(from manifest: AEXMLElement, metadata: AEXMLElement, to publication: inout Publication, _ rootFilePath: String) {
        // Read meta to see if any Link is referenced as the Cover.
        let coverId: String? = metadata["meta"].all(withAttributes: ["name" : "cover"])?.first?.attributes["content"]

        // Get the manifest children items
        guard let manifestItems = manifest["item"].all else {
            log(.warning, "Manifest have no children elements.")
            return
        }
        
        // Creates an Link for each of them and add it to the ressources.
        for item in manifestItems {
            // Must have an ID.
            guard let id = item.attributes["id"] else {
                log(.warning, "Manifest item MUST have an id, item ignored.")
                continue
            }
            guard let link = linkFromManifest(item, rootFilePath) else {
                log(.warning, "Can't parse link with ID \(id)")
                continue
            }
            
            // If the link reference a Smil resource, retrieve and fill it's duration.
            if link.type == "application/smil+xml" {
                // Retrieve the duration of the smil file in the otherMetadata.
                link.duration = publication.metadata.otherMetadata["#\(id)"] as? Double
            }
            
            // Add the "cover" rel to the link if it is referenced as the cover in the meta property.
            if let coverId = coverId, id == coverId {
                link.rels.append("cover")
            }
            
            publication.resources.append(link)
        }
    }

    /// Parse XML elements of the <ReadingOrder> in the package.opf file.
    /// They are only composed of an `idref` referencing one of the previously
    /// parsed resource (XML: idref -> id).
    ///
    /// - Parameters:
    ///   - readingOrder: The ReadingOrder XML element.
    ///   - publication: The `Publication` object with `.resource` and `.readingOrder`
    ///                  properties to fill.
    static internal func parseReadingOrder(from package: AEXMLElement, to publication: inout Publication) {
        // Get the readingOrder children items.
        var items = [AEXMLElement]()
        if let readingOrderItems = package["readingOrder"]["itemref"].all {
            items = readingOrderItems
        } else if let spineItems = package["spine"]["itemref"].all {
            items = spineItems
        }
      
        // Create a `Link` for each readingOrder item and add it to `Publication.readingOrder`.
        for item in items {
            // Find the ressource `idref` is referencing to.
            guard let idref = item.attributes["idref"],
                let index = publication.resources.index(where: { ($0.properties.otherProperties["id"] as? String) == idref }) else
            {
                continue
            }
            let link = publication.resources[index]
            
            // Parse the ressource properties and add it to the corresponding resource.
            if let propertyAttribute = item.attributes["properties"] {
                let properties = propertyAttribute.components(separatedBy: CharacterSet.whitespaces)
                parseProperties(&link.properties, from: properties)
            }
            // Retrieve `idref`, referencing a resource id.
            // Only linear items are added to the readingOrder.
            guard isLinear(item.attributes["linear"]) else {
                continue
            }
            // Move ressource to `.readingOrder` and remove it from `.ressources`.
            publication.readingOrder.append(link)
            publication.resources.remove(at: index)
        }
    }

    /// Determine if the xml attribute correspond to the linear one.
    ///
    /// - Parameter linear: The linear attribute value, if any.
    /// - Returns: True if it's linear, false if not.
    static fileprivate func isLinear(_ linear: String?) -> Bool {
        if linear != nil, linear?.lowercased() == "no" {
            return false
        }
        return true
    }

    // MARK: - Fileprivate Methods.

    /// Generate a `Link` form the given manifest's XML element.
    ///
    /// - Parameter item: The XML element, or manifest XML item.
    /// - Returns: The `Link` representing the manifest XML item.
    static fileprivate func linkFromManifest(_ item: AEXMLElement, _ rootFilePath: String) -> Link? {
        guard let href = item.attributes["href"] else {
            return nil
        }
        
        let propertiesArray = item.attributes["properties"]?.components(separatedBy: .whitespaces) ?? []

        var rels: [String] = []
        if propertiesArray.contains("nav") {
            rels.append("contents")
        }
        if propertiesArray.contains("cover-image") {
            rels.append("cover")
        }
        
        var properties = Properties()
        parseProperties(&properties, from: propertiesArray)
        
        if let id = item.attributes["id"] {
            properties.otherProperties["id"] = id
        }

        return Link(
            href: normalize(base: rootFilePath, href: href),
            type: item.attributes["media-type"],
            rels: rels,
            properties: properties
        )
    }

    /// Parse properties string array and return a Properties object.
    ///
    /// - Parameter propertiesArray: The array of properties strings.
    /// - Returns: The Properties instance created from the strings array info.
    static fileprivate func parseProperties(_ properties: inout Properties, from propertiesArray: [String]) {
        // Look if item have any properties.
        for property in propertiesArray {
            switch property {
            /// Contains
            case "scripted":
                properties.contains.append("js")
            case "mathml":
                properties.contains.append("mathml")
            case "onix-record":
                properties.contains.append("onix")
            case "svg":
                properties.contains.append("svg")
            case "xmp-record":
                properties.contains.append("xmp")
            case "remote-resources":
                properties.contains.append("remote-resources")
            /// Page
            case "page-spread-left":
                properties.page = .left
            case "page-spread-right":
                properties.page = .right
            case "page-spread-center":
                properties.page = .center
            /// Spread
            case "rendition:spread-none":
                properties.spread = .none
            case "rendition:spread-auto":
                properties.spread = .none
            case "rendition:spread-landscape":
                properties.spread = .landscape
            case "rendition:spread-portrait":
                // `portrait` is deprecated and should fallback to `both`.
                // See. https://readium.org/architecture/streamer/parser/metadata#epub-3x-11
                properties.spread = .both
            case "rendition:spread-both":
                properties.spread = .both
            /// Layout
            case "rendition:layout-reflowable":
                properties.layout = .reflowable
            case "rendition:layout-pre-paginated":
                properties.layout = .fixed
            /// Orientation
            case "rendition:orientation-auto":
                properties.orientation = .auto
            case "rendition:orientation-landscape":
                properties.orientation = .landscape
            case "rendition:orientation-portrait":
                properties.orientation = .portrait
            /// Rendition
            case "rendition:flow-auto":
                properties.overflow = .auto
            case "rendition:flow-paginated":
                properties.overflow = .paginated
            case "rendition:flow-scrolled-continuous":
                properties.overflow = .scrolledContinuous
            case "rendition:flow-scrolled-doc":
                properties.overflow = .scrolled
            default:
                continue
            }
        }
    }
}

