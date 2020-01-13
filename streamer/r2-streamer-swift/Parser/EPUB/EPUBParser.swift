//
//  EPUBParser.swift
//  r2-streamer-swift
//
//  Created by Olivier Körner on 08/12/2016.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import R2Shared
import Fuzi

/// Epub related constants.
struct EPUBConstant {
    /// Lcpl file path.
    public static let lcplFilePath = "META-INF/license.lcpl"
    /// Epub mime-type.
    public static let mimetype = "application/epub+zip"
    /// http://www.idpf.org/oebps/ (Legacy).
    public static let mimetypeOEBPS = "application/oebps-package+xml"
    /// Media Overlays URL.
    public static let mediaOverlayURL = "media-overlay?resource="
}

/// Errors thrown during the parsing of the EPUB
///
/// - wrongMimeType: The mimetype file is missing or its content differs from
///                 "application/epub+zip" (expected).
/// - missingFile: A file is missing from the container at `path`.
/// - xmlParse: An XML parsing error occurred.
/// - missingElement: An XML element is missing.
public enum EPUBParserError: Error {
    /// The mimetype of the EPUB is not valid.
    case wrongMimeType
    case missingFile(path: String)
    case xmlParse(underlyingError: Error)
    /// Missing rootfile in `container.xml`.
    case missingRootfile
}

@available(*, deprecated, renamed: "EPUBParserError")
public typealias EpubParserError = EPUBParserError

extension EpubParser: Loggable {}

/// An EPUB container parser that extracts the information from the relevant
/// files and builds a `Publication` instance out of it.
final public class EpubParser: PublicationParser {
    /// Parses the EPUB (file/directory) at `fileAtPath` and generate the
    /// corresponding `Publication` and `Container`.
    ///
    /// - Parameter url: The path to the epub file.
    /// - Returns: The Resulting publication, and a callback for parsing the
    ///            possibly DRM encrypted in the publication. The callback need
    ///            to be called by sending back the DRM object (or nil).
    ///            The point is to get DRM informations in the DRM object, and
    ///            inform the decypher() function in  the DRM object to allow
    ///            the fetcher to decypher encrypted resources.
    /// - Throws: `EPUBParserError.wrongMimeType`,
    ///           `EPUBParserError.xmlParse`,
    ///           `EPUBParserError.missingFile`
    static public func parse(at url: URL) throws -> (PubBox, PubParsingCallback) {
        let path = url.path
        // Generate the `Container` for `fileAtPath`
        var container = try generateContainerFrom(fileAtPath: path)

        // Parse OPF file (Metadata, ReadingOrder, Resource).
        var publication = try OPFParser(container: container).parsePublication()
        publication.positionListFactory = makePositionListFactory(container: container)
        
        // Parse navigation tables.
        parseNavigationDocument(from: container, to: &publication)
        if publication.tableOfContents.isEmpty || publication.pageList.isEmpty {
            parseNCXDocument(from: container, to: &publication)
        }
        
        // Check if the publication is DRM protected.
        let drm = scanForDRM(in: container)
        // Parse the META-INF/Encryption.xml.
        parseEncryption(from: container, to: &publication, drm)
        
        func parseRemainingResource(protectedBy drm: DRM?) throws {
            /// The folowing resources could be encrypted, hence we use the fetcher.
            let fetcher = try Fetcher(publication: publication, container: container)

            container.drm = drm

            fillEncryptionProfile(forLinksIn: publication, using: drm)
            try parseMediaOverlay(from: fetcher, to: &publication)
        }
        container.drm = drm
        return ((publication, container), parseRemainingResource)
    }

    // MARK: - Internal Methods.

    /// Parse the Encryption.xml EPUB file. It contains the informationg about
    /// encrypted resources and how to decrypt them.
    private static func parseEncryption(from container: Container, to publication: inout Publication, _ drm: DRM?) {
        guard let parser = try? EPUBEncryptionParser(container: container, drm: drm) else {
            return
        }

        // Adds the encryption information to the `Link` with matching `href`.
        for (href, encryption) in parser.parseEncryptions() {
            guard let link = publication.link(withHref: href) else {
                continue
            }
            link.properties.encryption = encryption
        }
    }

    /// WIP, currently only LCP.
    /// Scan Container (but later Publication too probably) to know if any DRM
    /// are protecting the publication.
    ///
    /// - Parameter in: The Publication's Container.
    /// - Returns: The DRM if any found.
    private static func scanForDRM(in container: Container) -> DRM? {
        /// LCP.
        // Check if a LCP license file is present in the container.
        if ((try? container.data(relativePath: EPUBConstant.lcplFilePath)) != nil) {
            return DRM(brand: .lcp)
        }
        return nil
    }

    /// Attempt to fill the `Publication`'s `tableOfContent`, `landmarks`, `pageList` and `listOfX` links collections using the navigation document.
    ///
    /// - Parameters:
    ///   - container: The Epub container.
    ///   - publication: The Epub publication.
    private static func parseNavigationDocument(from container: Container, to publication: inout Publication) {
        // Get the link in the readingOrder pointing to the Navigation Document.
        guard let navLink = publication.link(withRel: "contents"),
            let navDocumentData = try? container.data(relativePath: navLink.href) else
        {
            return
        }
        
        // Get the location of the navigation document in order to normalize href paths.
        let navigationDocument = NavigationDocumentParser(data: navDocumentData, at: navLink.href)

        publication.tableOfContents = navigationDocument.links(for: .tableOfContents)
        publication.pageList = navigationDocument.links(for: .pageList)
        publication.landmarks = navigationDocument.links(for: .landmarks)
        publication.listOfAudioFiles = navigationDocument.links(for: .listOfAudiofiles)
        publication.listOfIllustrations = navigationDocument.links(for: .listOfIllustrations)
        publication.listOfTables = navigationDocument.links(for: .listOfTables)
        publication.listOfVideos = navigationDocument.links(for: .listOfVideos)
    }

    /// Attempt to fill `Publication.tableOfContent`/`.pageList` using the NCX
    /// document. Will only modify the Publication if it has not be filled
    /// previously (using the Navigation Document).
    ///
    /// - Parameters:
    ///   - container: The Epub container.
    ///   - publication: The Epub publication.
    private static func parseNCXDocument(from container: Container, to publication: inout Publication) {
        // Get the link in the readingOrder pointing to the NCX document.
        guard let ncxLink = publication.resources.first(where: { $0.type == "application/x-dtbncx+xml" }),
            let ncxDocumentData = try? container.data(relativePath: ncxLink.href) else
        {
            return
        }
        
        let ncx = NCXParser(data: ncxDocumentData, at: ncxLink.href)
        
        if publication.tableOfContents.isEmpty {
            publication.tableOfContents = ncx.links(for: .tableOfContents)
        }
        if publication.pageList.isEmpty {
            publication.pageList = ncx.links(for: .pageList)
        }
    }

    /// Parse the mediaOverlays informations contained in the ressources then
    /// parse the associted SMIL files to populate the MediaOverlays objects
    /// in each of the ReadingOrder's Links.
    ///
    /// - Parameters:
    ///   - container: The Epub Container.
    ///   - publication: The Publication object representing the Epub data.
    private static func parseMediaOverlay(from fetcher: Fetcher, to publication: inout Publication) throws {
        let mediaOverlays = publication.resources.filter({ $0.type ==  "application/smil+xml"})

        guard !mediaOverlays.isEmpty else {
            log(.info, "No media-overlays found in the Publication.")
            return
        }
        for mediaOverlayLink in mediaOverlays {
            let node = MediaOverlayNode()
            
            guard let smilData = try? fetcher.data(forLink: mediaOverlayLink),
                let smilXml = try? XMLDocument(data: smilData) else
            {
                throw OPFParserError.invalidSmilResource
            }

            smilXml.definePrefix("smil", forNamespace: "http://www.w3.org/ns/SMIL")
            smilXml.definePrefix("epub", forNamespace: "http://www.idpf.org/2007/ops")
            guard let body = smilXml.firstChild(xpath: "./smil:body") else {
                continue
            }

            node.role.append("section")
            if let textRef = body.attr("textref") { // Prevent the crash on the japanese book
                node.text = normalize(base: mediaOverlayLink.href, href: textRef)
            }
            // get body parameters <par>a
            let href = mediaOverlayLink.href
            SMILParser.parseParameters(in: body, withParent: node, base: href)
            SMILParser.parseSequences(in: body, withParent: node, publicationReadingOrder: &publication.readingOrder, base: href)
            // "/??/xhtml/mo-002.xhtml#mo-1" => "/??/xhtml/mo-002.xhtml"
            guard let baseHref = node.text?.components(separatedBy: "#")[0],
                let link = publication.readingOrder.first(where: { baseHref.contains($0.href) }) else
            {
                continue
            }
            link.mediaOverlays.append(node)
            link.properties.mediaOverlay = EPUBConstant.mediaOverlayURL + link.href
        }
    }

    /// Generate a Container instance for the file at `fileAtPath`. It handles
    /// 2 cases, epub files and unwrapped epub directories.
    ///
    /// - Parameter path: The absolute path of the file.
    /// - Returns: The generated Container.
    /// - Throws: `EPUBParserError.missingFile`.
    private static func generateContainerFrom(fileAtPath path: String) throws -> Container {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw EPUBParserError.missingFile(path: path)
        }
        
        guard let container: Container = {
            if isDirectory.boolValue {
                return DirectoryContainer(directory: path, mimetype: EPUBConstant.mimetype)
            } else {
                return ArchiveContainer(path: path, mimetype: EPUBConstant.mimetype)
            }
        }() else {
            throw EPUBParserError.missingFile(path: path)
        }
        
        container.rootFile.rootFilePath = try EPUBContainerParser(container: container).parseRootFilePath()

        return container
    }

    /// Called in the callback when the DRM has been informed of the encryption
    /// scheme, in order to fill this information in the encrypted links.
    ///
    /// - Parameters:
    ///   - publication: The Publication.
    ///   - drm: The `DRM` object.
    private static func fillEncryptionProfile(forLinksIn publication: Publication, using drm: DRM?) {
        guard let drm = drm else {
            return
        }
        for link in publication.resources {
            if link.properties.encryption?.scheme == drm.scheme.rawValue{
                link.properties.encryption?.profile = drm.license?.encryptionProfile
            }
        }
        for link in publication.readingOrder {
            if link.properties.encryption?.scheme == drm.scheme.rawValue {
                link.properties.encryption?.profile = drm.license?.encryptionProfile
            }
        }
    }
    
    /// Factory to create an EPUB's positionList.
    private static func makePositionListFactory(container: Container) -> (Publication) -> [Locator] {
        return { publication in
            var lastPositionOfPreviousResource = 0
            var positionList = publication.readingOrder.flatMap { link -> [Locator] in
                let (lastPosition, positionList): (Int, [Locator]) = {
                    if publication.metadata.rendition.layout(of: link) == .fixed {
                        return makeFixedPositionList(of: link, from: lastPositionOfPreviousResource)
                    } else {
                        return makeReflowablePositionList(of: link, in: container, from: lastPositionOfPreviousResource)
                    }
                }()
                lastPositionOfPreviousResource = lastPosition
                return positionList
            }
            
            // Calculates totalProgression
            let totalPageCount = positionList.count
            if totalPageCount > 0 {
                positionList = positionList.map { locator in
                    var locator = locator
                    if let position = locator.locations.position {
                        locator.locations.totalProgression = Double(position - 1) / Double(totalPageCount)
                    }
                    return locator
                }
            }
            
            return positionList
        }
    }
    
    private static func makeFixedPositionList(of link: Link, from startPosition: Int) -> (Int, [Locator]) {
        let position = startPosition + 1
        let positionList = [Locator(
            href: link.href,
            type: link.type ?? "text/html",
            locations: Locations(
                progression: 0,
                position: position
            )
        )]
        return (position, positionList)
    }
    
    private static func makeReflowablePositionList(of link: Link, in container: Container, from startPosition: Int) -> (Int, [Locator]) {
        // If the resource is encrypted, we use the originalLength declared in encryption.xml instead of the ZIP entry length
        let length = link.properties.encryption?.originalLength
            ?? Int((try? container.dataLength(relativePath: link.href)) ?? 0)
        
        // Arbitrary byte length of a single page in a resource.
        let pageLength = 1024
        let pageCount = max(1, Int(ceil((Double(length) / Double(pageLength)))))
        
        let positionList = (1...pageCount).map { position in
            Locator(
                href: link.href,
                type: link.type ?? "text/html",
                locations: Locations(
                    progression: Double(position - 1) / Double(pageCount),
                    position: startPosition + position
                )
            )
        }
        return (startPosition + pageCount, positionList)
    }
    
}
