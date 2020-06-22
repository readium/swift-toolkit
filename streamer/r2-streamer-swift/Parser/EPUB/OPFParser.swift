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


// http://www.idpf.org/epub/30/spec/epub30-publications.html#title-type
// the six basic values of the "title-type" property specified by EPUB 3:
public enum EPUBTitleType: String {
    case main
    case subtitle
    case short
    case collection
    case edition
    case expanded
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
    private let document: Fuzi.XMLDocument

    /// iBooks Display Options XML file to use as a fallback for metadata.
    /// See https://github.com/readium/architecture/blob/master/streamer/parser/metadata.md#epub-2x-9
    private let displayOptions: Fuzi.XMLDocument?

    /// List of metadata declared in the package.
    private let metas: OPFMetaList
    
    /// Encryption information, indexed by resource HREF.
    private let encryptions: [String: Encryption]

    init(basePath: String, data: Data, displayOptionsData: Data? = nil, encryptions: [String: Encryption]) throws {
        self.basePath = basePath
        self.document = try Fuzi.XMLDocument(data: data)
        self.document.definePrefix("opf", forNamespace: "http://www.idpf.org/2007/opf")
        self.displayOptions = (displayOptionsData.map { try? Fuzi.XMLDocument(data: $0) }) ?? nil
        self.metas = OPFMetaList(document: self.document)
        self.encryptions = encryptions
    }
    
    convenience init(container: Container, encryptions: [String: Encryption] = [:]) throws {
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
            }(),
            encryptions: encryptions
        )
    }
    
    /// Parse the OPF file of the EPUB container and return a `Publication`.
    /// It also complete the informations stored in the container.
    func parsePublication() throws -> (version: String, metadata: Metadata, readingOrder: [Link], resources: [Link]) {
        let links = parseLinks()
        let (resources, readingOrder) = splitResourcesAndReadingOrderLinks(links)
        let metadata = EPUBMetadataParser(document: document, displayOptions: displayOptions, metas: metas)

        return (
            version: parseEPUBVersion(),
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
    private func parseLinks() -> [Link] {
        // Read meta to see if any Link is referenced as the Cover.
        let coverId = metas["cover"].first?.content

        let manifestItems = document.xpath("/opf:package/opf:manifest/opf:item")
        
        // Spine items indexed by IDRef
        let spineItemsKVs = document.xpath("/opf:package/opf:spine/opf:itemref")
            .compactMap { item in
                item.attr("idref").map { ($0, item) }
            }
        let spineItems = Dictionary(spineItemsKVs, uniquingKeysWith: { first, _ in first })

        return manifestItems.compactMap { manifestItem in
                // Must have an ID.
                guard let id = manifestItem.attr("id") else {
                    log(.warning, "Manifest item MUST have an id, item ignored.")
                    return nil
                }
            
                let isCover = (id == coverId)

                guard let link = makeLink(manifestItem: manifestItem, spineItem: spineItems[id], isCover: isCover) else {
                    log(.warning, "Can't parse link with ID \(id)")
                    return nil
                }

                return link
            }
    }

    /// Parses XML elements of the <spine> in the package.opf file.
    /// They are only composed of an `idref` referencing one of the previously parsed resource (XML: idref -> id).
    ///
    /// - Parameter manifestLinks: The `Link` parsed in the manifest items.
    /// - Returns: The `Link` in `resources` and in `readingOrder`, taken from the `manifestLinks`.
    private func splitResourcesAndReadingOrderLinks(_ manifestLinks: [Link]) -> (resources: [Link], readingOrder: [Link]) {
        var resources = manifestLinks
        var readingOrder: [Link] = []
        
        let spineItems = document.xpath("/opf:package/opf:spine/opf:itemref")
        for item in spineItems {
            // Find the `Link` that `idref` is referencing to from the `manifestLinks`.
            guard let idref = item.attr("idref"),
                let index = resources.firstIndex(withProperty: "id", matching: idref),
                // Only linear items are added to the readingOrder.
                item.attr("linear")?.lowercased() != "no" else
            {
                continue
            }
            
            readingOrder.append(resources[index])
            // `resources` should only contain the links that are not already in `readingOrder`.
            resources.remove(at: index)
        }
        
        return (resources, readingOrder)
    }

    private func makeLink(manifestItem: Fuzi.XMLElement, spineItem: Fuzi.XMLElement?, isCover: Bool) -> Link? {
        guard var href = manifestItem.attr("href")?.removingPercentEncoding else {
            return nil
        }
        
        href = normalize(base: basePath, href: href)

        // Merges the string properties found in the manifest and spine items.
        let stringProperties = "\(manifestItem.attr("properties") ?? "") \(spineItem?.attr("properties") ?? "")"
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        var rels: [String] = []
        if stringProperties.contains("nav") {
            rels.append("contents")
        }
        if isCover || stringProperties.contains("cover-image") {
            rels.append("cover")
        }

        var properties = parseStringProperties(stringProperties)
        
        if let encryption = encryptions[href]?.json, !encryption.isEmpty {
            properties["encrypted"] = encryption
        }

        let type = manifestItem.attr("media-type")
        var duration: Double?
        
        if let id = manifestItem.attr("id") {
            properties["id"] = id
            
            // If the link references a SMIL resource, retrieves and fills its duration.
            if MediaType.smil.matches(type), let durationMeta = metas["duration", in: .media, refining: id].first {
                duration = Double(SMILParser.smilTimeToSeconds(durationMeta.content))
            }
        }

        return Link(
            href: href,
            type: type,
            rels: rels,
            properties: Properties(properties),
            duration: duration
        )
    }

    /// Parse string properties into an `otherProperties` dictionary.
    private func parseStringProperties(_ properties: [String]) -> [String: Any] {
        var contains: [String] = []
        var layout: EPUBLayout?
        var orientation: Presentation.Orientation?
        var overflow: Presentation.Overflow?
        var page: Presentation.Page?
        var spread: Presentation.Spread?

        for property in properties {
            switch property {
            // Contains
            case "scripted":
                contains.append("js")
            case "mathml":
                contains.append("mathml")
            case "onix-record":
                contains.append("onix")
            case "svg":
                contains.append("svg")
            case "xmp-record":
                contains.append("xmp")
            case "remote-resources":
                contains.append("remote-resources")
            // Page
            case "page-spread-left":
                page = .left
            case "page-spread-right":
                page = .right
            case "page-spread-center", "rendition:page-spread-center":
                page = .center
            // Spread
            case "rendition:spread-none", "rendition:spread-auto":
                // If we don't qualify `.none` here it sets it to `nil`.
                spread = Presentation.Spread.none
            case "rendition:spread-landscape":
                spread = .landscape
            case "rendition:spread-portrait":
                // `portrait` is deprecated and should fallback to `both`.
                // See. https://readium.org/architecture/streamer/parser/metadata#epub-3x-11
                spread = .both
            case "rendition:spread-both":
                spread = .both
            // Layout
            case "rendition:layout-reflowable":
                layout = .reflowable
            case "rendition:layout-pre-paginated":
                layout = .fixed
            // Orientation
            case "rendition:orientation-auto":
                orientation = .auto
            case "rendition:orientation-landscape":
                orientation = .landscape
            case "rendition:orientation-portrait":
                orientation = .portrait
            // Rendition
            case "rendition:flow-auto":
                overflow = .auto
            case "rendition:flow-paginated":
                overflow = .paginated
            case "rendition:flow-scrolled-continuous", "rendition:flow-scrolled-doc":
                overflow = .scrolled
            default:
                continue
            }
        }
        
        var otherProperties: [String: Any] = [:]
        if !contains.isEmpty {
            otherProperties["contains"] = contains
        }
        if let layout = layout {
            otherProperties["layout"] = layout.rawValue
        }
        if let orientation = orientation {
            otherProperties["orientation"] = orientation.rawValue
        }
        if let overflow = overflow {
            otherProperties["overflow"] = overflow.rawValue
        }
        if let page = page {
            otherProperties["page"] = page.rawValue
        }
        if let spread = spread {
            otherProperties["spread"] = spread.rawValue
        }
        
        return otherProperties
    }

}

