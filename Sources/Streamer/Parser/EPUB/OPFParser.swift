//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumFuzi
import ReadiumShared

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
    private let baseURL: RelativeURL

    /// DOM representation of the OPF file.
    private let document: ReadiumFuzi.XMLDocument

    /// iBooks Display Options XML file to use as a fallback for metadata.
    /// See https://github.com/readium/architecture/blob/master/streamer/parser/metadata.md#epub-2x-9
    private let displayOptions: ReadiumFuzi.XMLDocument?

    /// List of metadata declared in the package.
    private let metas: OPFMetaList

    /// Encryption information, indexed by resource HREF.
    private let encryptions: [RelativeURL: Encryption]

    init(baseURL: RelativeURL, data: Data, displayOptionsData: Data? = nil, encryptions: [RelativeURL: Encryption]) throws {
        self.baseURL = baseURL
        document = try ReadiumFuzi.XMLDocument(data: data)
        document.defineNamespace(.opf)
        displayOptions = (displayOptionsData.map { try? ReadiumFuzi.XMLDocument(data: $0) }) ?? nil
        metas = OPFMetaList(document: document)
        self.encryptions = encryptions
    }

    convenience init(container: Container, opfHREF: RelativeURL, encryptions: [RelativeURL: Encryption] = [:]) async throws {
        guard let data = try? await container.readData(at: opfHREF) else {
            throw EPUBParserError.missingFile(path: opfHREF.string)
        }

        try await self.init(
            baseURL: opfHREF,
            data: data,
            displayOptionsData: {
                let iBooksHREF = AnyURL(string: "META-INF/com.apple.ibooks.display-options.xml")!
                let koboHREF = AnyURL(string: "META-INF/com.kobobooks.display-options.xml")!
                if let data = try? await container.readData(at: iBooksHREF) {
                    return data
                } else if let data = try? await container.readData(at: koboHREF) {
                    return data
                } else {
                    return nil
                }
            }(),
            encryptions: encryptions
        )
    }

    struct Package {
        let version: String
        let metadata: Metadata
        let readingOrder: [Link]
        let resources: [Link]
        let epub2Guide: [Link]
    }

    /// Parse the OPF file of the EPUB container and return a `Publication`.
    /// It also complete the informations stored in the container.
    func parsePublication() throws -> Package {
        let links = parseLinks()
        let (resources, readingOrder) = splitResourcesAndReadingOrderLinks(links)
        let metadata = EPUBMetadataParser(document: document, displayOptions: displayOptions, metas: metas)

        return try Package(
            version: parseEPUBVersion(),
            metadata: metadata.parse(),
            readingOrder: readingOrder,
            resources: resources,
            epub2Guide: parseEPUB2Guide()
        )
    }

    /// Retrieves the EPUB version from the package.opf XML document.
    private func parseEPUBVersion() -> String {
        // Default EPUB Version value, used when no version hes been specified (see OPF_2.0.1_draft 1.3.2).
        let defaultVersion = "1.2"
        return document.firstChild(xpath: "/opf:package")?.attr("version") ?? defaultVersion
    }

    /// Parses EPUB 2 <guide> element into a list of `Link`.
    ///
    /// https://idpf.org/epub/20/spec/OPF_2.0.1_draft.htm#TOC2.6
    private func parseEPUB2Guide() -> [Link] {
        document.xpath("/opf:package/opf:guide/opf:reference")
            .compactMap { node -> Link? in
                guard
                    let relativeHref = node.attr("href").flatMap(RelativeURL.init(epubHREF:)),
                    let href = baseURL.resolve(relativeHref)
                else {
                    return nil
                }

                return Link(
                    href: href.string,
                    title: node.attr("title")?.orNilIfBlank(),
                    rel: node.attr("type").flatMap(LinkRelation.init(epub2Type:))
                )
            }
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
                  let index = resources.firstIndex(where: { $0.properties["id"] as? String == idref }),
                  // Only linear items are added to the readingOrder.
                  item.attr("linear")?.lowercased() != "no"
            else {
                continue
            }

            readingOrder.append(resources[index])
            // `resources` should only contain the links that are not already in `readingOrder`.
            resources.remove(at: index)
        }

        return (resources, readingOrder)
    }

    private func makeLink(manifestItem: ReadiumFuzi.XMLElement, spineItem: ReadiumFuzi.XMLElement?, isCover: Bool) -> Link? {
        guard
            let relativeHref = manifestItem.attr("href").flatMap(RelativeURL.init(epubHREF:)),
            let href = baseURL.resolve(relativeHref)?.normalized
        else {
            return nil
        }

        // Merges the string properties found in the manifest and spine items.
        let stringProperties = "\(manifestItem.attr("properties") ?? "") \(spineItem?.attr("properties") ?? "")"
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        var rels: [LinkRelation] = []
        if stringProperties.contains("nav") {
            rels.append(.contents)
        }
        if isCover || stringProperties.contains("cover-image") {
            rels.append(.cover)
        }

        var properties = parseStringProperties(stringProperties)

        if let encryption = encryptions[href]?.json, !encryption.isEmpty {
            properties["encrypted"] = encryption
        }

        let type = manifestItem.attr("media-type")

        if let id = manifestItem.attr("id") {
            properties["id"] = id
        }

        return Link(
            href: href.string,
            mediaType: type.flatMap { MediaType($0) },
            rels: rels,
            properties: Properties(properties)
        )
    }

    /// Parse string properties into an `otherProperties` dictionary.
    private func parseStringProperties(_ properties: [String]) -> [String: Any] {
        var contains: [String] = []
        var page: Properties.Page?

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
            default:
                continue
            }
        }

        var otherProperties: [String: Any] = [:]
        if !contains.isEmpty {
            otherProperties["contains"] = contains
        }
        if let page = page {
            otherProperties["page"] = page.rawValue
        }

        return otherProperties
    }
}
