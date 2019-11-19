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

import Fuzi
import R2Shared


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

public enum OPFParserError: Error {
    /// The Epub have no title. Title is mandatory.
    case missingPublicationTitle
    /// Smile resource couldn't be parsed.
    case invalidSmilResource
}

/// EpubParser support class, able to parse the OPF package document.
/// OPF: Open Packaging Format.
final class OPFParser: Loggable {
    
    /// Relative path to the OPF in the EPUB container
    private let basePath: String
    
    /// DOM representation of the OPF file.
    private let document: XMLDocument

    /// iBooks Display Options XML file to use as a fallback for metadata.
    /// See https://github.com/readium/architecture/blob/master/streamer/parser/metadata.md#epub-2x-9
    private let displayOptions: XMLDocument?
    
    /// List of metadata declared in the package.
    private let metas: OPFMetaList

    init(basePath: String, data: Data, displayOptionsData: Data? = nil) throws {
        self.basePath = basePath
        self.document = try XMLDocument(data: data)
        self.document.definePrefix("opf", forNamespace: "http://www.idpf.org/2007/opf")
        self.displayOptions = (displayOptionsData.map { try? XMLDocument(data: $0) }) ?? nil
        self.metas = OPFMetaList(document: self.document)
    }
    
    convenience init(container: Container) throws {
        let opfPath = container.rootFile.rootFilePath
        try self.init(
            basePath: opfPath,
            data: try container.data(relativePath: opfPath),
            displayOptionsData: {
                let iBooksPath = "META-INF/com.apple.ibooks.display-options.xml"
                let koboPath = "META-INF/com.kobobooks.display-options.xml"
                return (try? container.data(relativePath: iBooksPath))
                    ?? (try? container.data(relativePath: koboPath))
                    ?? nil
            }()
        )
    }
    
    /// Parse the OPF file of the EPUB container and return a `Publication`.
    /// It also complete the informations stored in the container.
    func parsePublication() throws -> Publication {
        let manifestLinks = parseManifestLinks()
        let (resources, readingOrder) = parseResourcesAndReadingOrderLinks(manifestLinks)
        let metadata = EPUBMetadataParser(document: document, displayOptions: displayOptions, metas: metas)

        return Publication(
            format: .epub,
            formatVersion: parseEPUBVersion(),
            metadata: try metadata.parse(),
            readingOrder: readingOrder,
            resources: resources
        )
    }

    /// Retrieves the EPUB version from the package.opf XML document.
    private func parseEPUBVersion() -> String {
        // Default EPUB Version value, used when no version hes been specified (see OPF_2.0.1_draft 1.3.2).
        let defaultVersion = "1.2"
        return document.firstChild(xpath: "/opf:package")?.attr("version") ?? defaultVersion
    }
    
    /// Parses XML elements of the <Manifest> in the package.opf file as a list of `Link`.
    private func parseManifestLinks() -> [Link] {
        // Read meta to see if any Link is referenced as the Cover.
        let coverId = metas["cover"].first?.content

        // Get the manifest children items
        let manifestItems = document.xpath("/opf:package/opf:manifest/opf:item")
        
        return manifestItems.compactMap { item in
                // Must have an ID.
                guard let id = item.attr("id") else {
                    log(.warning, "Manifest item MUST have an id, item ignored.")
                    return nil
                }
                guard let link = makeLink(from: item) else {
                    log(.warning, "Can't parse link with ID \(id)")
                    return nil
                }
    
                // If the link reference a Smil resource, retrieve and fill its duration.
                if link.type == "application/smil+xml",
                    let durationMeta = metas["duration", in: .media, refining: id].first,
                    let duration = Double(SMILParser.smilTimeToSeconds(durationMeta.content)) {
                    link.duration = duration
                }
    
                // Add the "cover" rel to the link if it is referenced as the cover in the meta property.
                if let coverId = coverId, id == coverId {
                    link.rels.append("cover")
                }
    
                return link
            }
    }

    /// Parses XML elements of the <ReadingOrder> in the package.opf file.
    /// They are only composed of an `idref` referencing one of the previously parsed resource (XML: idref -> id).
    ///
    /// - Parameter manifestLinks: The `Link` parsed in the manifest items.
    /// - Returns: The `Link` in `resources` and in `readingOrder`, taken from the `manifestLinks`.
    private func parseResourcesAndReadingOrderLinks(_ manifestLinks: [Link]) -> (resources: [Link], readingOrder: [Link]) {
        var resources = manifestLinks
        var readingOrder: [Link] = []
        
        // Get the readingOrder children items.
        let readingOrderItems = document.xpath("/opf:package/opf:readingOrder/opf:itemref|/opf:package/opf:spine/opf:itemref")
        for item in readingOrderItems {
            // Find the `Link` that `idref` is referencing to from the `manifestLinks`.
            guard let idref = item.attr("idref"),
                let index = resources.firstIndex(withProperty: "id", matching: idref) else
            {
                continue
            }
            
            // Parse the additional link properties.
            let link = resources[index]
            if let propertyAttribute = item.attr("properties") {
                let properties = propertyAttribute.components(separatedBy: CharacterSet.whitespaces)
                parseProperties(&link.properties, from: properties)
            }
            
            // Retrieve `idref`, referencing a resource id.
            // Only linear items are added to the readingOrder.
            guard isLinear(item.attr("linear")) else {
                continue
            }
            
            readingOrder.append(link)
            // The resources should only contain the links that are not already in the readingOrder
            resources.remove(at: index)
        }
        
        return (resources, readingOrder)
    }

    /// Returns whether the XML attribute correspond to the linear one.
    /// - Parameter linear: The linear attribute value, if any.
    private func isLinear(_ linear: String?) -> Bool {
        if linear != nil, linear?.lowercased() == "no" {
            return false
        }
        return true
    }

    /// Generate a `Link` form the given manifest's XML element.
    ///
    /// - Parameter item: The XML element, or manifest XML item.
    /// - Returns: The `Link` representing the manifest XML item.
    private func makeLink(from manifestItem: XMLElement) -> Link? {
        guard let href = manifestItem.attr("href")?.removingPercentEncoding else {
            return nil
        }
        
        let propertiesArray = manifestItem.attr("properties")?.components(separatedBy: .whitespaces) ?? []

        var rels: [String] = []
        if propertiesArray.contains("nav") {
            rels.append("contents")
        }
        if propertiesArray.contains("cover-image") {
            rels.append("cover")
        }
        
        var properties = Properties()
        parseProperties(&properties, from: propertiesArray)
        
        if let id = manifestItem.attr("id") {
            properties.otherProperties["id"] = id
        }

        return Link(
            href: normalize(base: basePath, href: href),
            type: manifestItem.attr("media-type"),
            rels: rels,
            properties: properties
        )
    }

    /// Parse properties string array and return a Properties object.
    ///
    /// - Parameter propertiesArray: The array of properties strings.
    /// - Returns: The Properties instance created from the strings array info.
    private func parseProperties(_ properties: inout Properties, from propertiesArray: [String]) {
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
            case "page-spread-center", "rendition:page-spread-center":
                properties.page = .center
            /// Spread
            case "rendition:spread-none", "rendition:spread-auto":
                // If we don't qualify `.none` here it sets it to `nil`.
                properties.spread = EPUBRendition.Spread.none
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

