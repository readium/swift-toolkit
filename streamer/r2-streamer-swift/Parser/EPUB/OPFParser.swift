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
    static internal func parseOPF(from container: Container) throws -> Publication {
        let rootFilePath = container.rootFile.rootFilePath
        
        // Get the package.opf XML document from the container.
        let documentData = try container.data(relativePath: rootFilePath)
        let document = try AEXMLDocument(xml: documentData)
        let displayOptions = parseDisplayOptionsDocument(from: container)

        let epubVersion = parseEpubVersion(from: document)
        let manifestLinks = parseManifestLinks(from: document, at: rootFilePath)
        let (resources, readingOrder) = parseResourcesAndReadingOrder(from: document, manifestLinks: manifestLinks)
        let metadata = EPUBMetadataParser(document: document, displayOptions: displayOptions, epubVersion: epubVersion)

        return Publication(
            format: .epub,
            formatVersion: String(epubVersion),
            metadata: try metadata.parse(),
            readingOrder: readingOrder,
            resources: resources
        )
    }
    
    /// Parses iBooks Display Options XML file to use as a fallback.
    /// See https://github.com/readium/architecture/blob/master/streamer/parser/metadata.md#epub-2x-9
    static func parseDisplayOptionsDocument(from container: Container) -> AEXMLDocument? {
        let iBooksPath = "META-INF/com.apple.ibooks.display-options.xml"
        let koboPath = "META-INF/com.kobobooks.display-options.xml"
        guard let documentData = (try? container.data(relativePath: iBooksPath)) ?? (try? container.data(relativePath: koboPath)) else {
            return nil
        }
        var options = AEXMLOptions()
        options.parserSettings.shouldProcessNamespaces = true
        return try? AEXMLDocument(xml: documentData, options: options)
    }

    /// Parses XML elements of the <Manifest> in the package.opf file as a list of `Link`.
    ///
    /// - Parameters:
    ///   - manifest: The Manifest XML element.
    ///   - metadata: The metadata XML element.
    ///   - coverId: The coverId to identify the cover ressource and tag it.
    static internal func parseManifestLinks(from document: AEXMLElement, at rootFilePath: String) -> [Link] {
        let durations = parseMediaDurations(from: document)

        // Read meta to see if any Link is referenced as the Cover.
        let coverId: String? = document["package"]["metadata"]["meta"]
            .all(withAttributes: ["name" : "cover"])?
            .first?.attributes["content"]

        // Get the manifest children items
        guard let manifestItems = document["package"]["manifest"]["item"].all else {
            log(.warning, "Manifest have no children elements.")
            return []
        }
        
        return manifestItems.compactMap { item in
                // Must have an ID.
                guard let id = item.attributes["id"] else {
                    log(.warning, "Manifest item MUST have an id, item ignored.")
                    return nil
                }
                guard let link = linkFromManifest(item, rootFilePath) else {
                    log(.warning, "Can't parse link with ID \(id)")
                    return nil
                }
    
                // If the link reference a Smil resource, retrieve and fill its duration.
                if link.type == "application/smil+xml", let duration = durations["#\(id)"] {
                    link.duration = duration
                }
    
                // Add the "cover" rel to the link if it is referenced as the cover in the meta property.
                if let coverId = coverId, id == coverId {
                    link.rels.append("cover")
                }
    
                return link
            }
    }

    /// Parse the metadata>meta>property=media:duration elements from the
    /// metadata. These meta are related to the Media Overlays, they give the
    /// smil file audio playback time.
    /// Metadata -> e.g. : ["#smil-1": "00:01:24.687"]
    ///
    /// - Parameter document: The OPF XML element.
    /// - Returns: Mapping between the SMIL ID and its duration.
    static internal func parseMediaDurations(from document: AEXMLElement) -> [String: Double]
    {
        guard let metas = document["package"]["metadata"]["meta"].all else {
            return [:]
        }
        
        return metas
            .filter { $0.attributes["property"] == "media:duration" }
            .reduce([:]) { durations, item in
                var durations = durations
                if let property = item.attributes["refines"],
                    let value = item.value,
                    let duration = Double(SMILParser.smilTimeToSeconds(value))
                {
                    durations[property] = duration
                }
                
                return durations
        }
    }

    /// Parse XML elements of the <ReadingOrder> in the package.opf file.
    /// They are only composed of an `idref` referencing one of the previously
    /// parsed resource (XML: idref -> id).
    ///
    /// - Parameter manifestLinks: The `Link` parsed in the manifest items.
    /// - Returns: The `Link` in `resources` and in `readingOrder`, taken from the `manifestLinks`.
    static internal func parseResourcesAndReadingOrder(from document: AEXMLElement, manifestLinks: [Link]) -> (resources: [Link], readingOrder: [Link]) {
        var resources = manifestLinks
        var readingOrder: [Link] = []
        
        // Get the readingOrder children items.
        let readingOrderItems = document["package"]["readingOrder"]["itemref"].all
            ?? document["package"]["spine"]["itemref"].all
            ?? []
        
        for item in readingOrderItems {
            // Find the `Link` that `idref` is referencing to from the `manifestLinks`.
            guard let idref = item.attributes["idref"],
                let index = resources.firstIndex(withProperty: "id", matching: idref) else
            {
                continue
            }
            
            // Parse the additional link properties.
            let link = resources[index]
            if let propertyAttribute = item.attributes["properties"] {
                let properties = propertyAttribute.components(separatedBy: CharacterSet.whitespaces)
                parseProperties(&link.properties, from: properties)
            }
            
            // Retrieve `idref`, referencing a resource id.
            // Only linear items are added to the readingOrder.
            guard isLinear(item.attributes["linear"]) else {
                continue
            }
            
            readingOrder.append(link)
            // The resources should only contain the links that are not already in the readingOrder
            resources.remove(at: index)
        }
        
        return (resources, readingOrder)
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

    /// Retrieve the EPUB version from the package.opf XML document else set it
    /// to the default value `EpubConstant.defaultEpubVersion`.
    ///
    /// - Parameter containerXml: The XML container instance.
    /// - Returns: The OPF file path.
    static fileprivate func parseEpubVersion(from document: AEXMLDocument) -> Double {
        let version: Double
        
        if let versionAttribute = document["package"].attributes["version"],
            let versionNumber = Double(versionAttribute)
        {
            version = versionNumber
        } else {
            version = EpubConstant.defaultEpubVersion
        }
        return version
    }
    
}

