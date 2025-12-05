//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumFuzi
import ReadiumShared

final class EPUBManifestParser {
    private let container: Container
    private let encryptions: [RelativeURL: Encryption]

    init(container: Container, encryptions: [RelativeURL: Encryption]) {
        self.container = container
        self.encryptions = encryptions
    }

    func parseManifest() async throws -> Manifest {
        let opfHREF = try await EPUBContainerParser(container: container).parseOPFHREF()

        // Extracts metadata and links from the OPF.
        let opfPackage = try await OPFParser(container: container, opfHREF: opfHREF, encryptions: encryptions).parsePublication()
        let metadata = opfPackage.metadata
        let links = opfPackage.readingOrder + opfPackage.resources

        var manifest = await Manifest(
            metadata: metadata,
            readingOrder: opfPackage.readingOrder,
            resources: opfPackage.resources,
            subcollections: parseCollections(in: container, package: opfPackage, links: links)
        )

        fillReadingOrderRels(in: &manifest)

        return manifest
    }

    /// Extracts the link relations from the landmarks to fill in the reading
    /// order.
    private func fillReadingOrderRels(in manifest: inout Manifest) {
        guard
            let landmarks = manifest.subcollections["landmarks"],
            !landmarks.isEmpty
        else {
            return
        }
        let links = landmarks.flatMap(\.links)
        let startURL = links.firstWithRel(.start)?.url()
        let coverURL = links.firstWithRel(.cover)?.url()
        let contentsURL = links.firstWithRel(.contents)?.url()

        manifest.readingOrder = manifest.readingOrder.map { link in
            var link = link
            let url = link.url()
            if let coverURL = coverURL, url.isEquivalentTo(coverURL) {
                link.rels.append(.cover)
            }
            if let startURL = startURL, url.isEquivalentTo(startURL) {
                link.rels.append(.start)
            }
            if let contentsURL = contentsURL, url.isEquivalentTo(contentsURL) {
                link.rels.append(.contents)
            }

            return link
        }
    }

    private func parseCollections(
        in container: Container,
        package: OPFParser.Package,
        links: [Link]
    ) async -> [String: [PublicationCollection]] {
        var collections = await parseNavigationDocument(in: container, links: links)
        if collections["toc"]?.first?.links.isEmpty != false {
            // Falls back on the NCX tables.
            await collections.merge(parseNCXDocument(in: container, links: links), uniquingKeysWith: { first, _ in first })
        }

        // EPUB 3 Reading Systems must ignore the guide element when provided in
        // EPUB 3 Publications whose EPUB Navigation Document includes the
        // landmarks feature.
        // https://idpf.org/epub/30/spec/epub30-publications.html#sec-guide-elem
        if !collections.keys.contains("landmarks"), !package.epub2Guide.isEmpty {
            // EPUB 2.0 doesn't have a landmarks collection, so we use the guide
            // as a fallback. If an EPUB 3.0+ file does not have landmarks, it
            // will use guide instead.
            collections["landmarks"] = [PublicationCollection(links: package.epub2Guide)]
        }

        return collections
    }

    /// Attempt to fill the `Publication`'s `tableOfContent`, `landmarks`, `pageList` and `listOfX` links collections using the navigation document.
    private func parseNavigationDocument(in container: Container, links: [Link]) async -> [String: [PublicationCollection]] {
        // Get the link in the readingOrder pointing to the Navigation Document.
        guard
            let navLink = links.firstWithRel(.contents),
            let navURI = RelativeURL(string: navLink.href),
            let navDocumentData = try? await container.readData(at: navURI)
        else {
            return [:]
        }

        // Get the location of the navigation document in order to normalize href paths.
        let navigationDocument = NavigationDocumentParser(data: navDocumentData, at: navURI)

        var collections: [String: [PublicationCollection]] = [:]
        func addCollection(_ type: NavigationDocumentParser.NavType, role: String) {
            let links = navigationDocument.links(for: type)
            if !links.isEmpty {
                collections[role] = [PublicationCollection(links: links)]
            }
        }

        addCollection(.tableOfContents, role: "toc")
        addCollection(.pageList, role: "pageList")
        addCollection(.landmarks, role: "landmarks")
        addCollection(.listOfAudiofiles, role: "loa")
        addCollection(.listOfIllustrations, role: "loi")
        addCollection(.listOfTables, role: "lot")
        addCollection(.listOfVideos, role: "lov")

        return collections
    }

    /// Attempt to fill `Publication.tableOfContent`/`.pageList` using the NCX
    /// document. Will only modify the Publication if it has not be filled
    /// previously (using the Navigation Document).
    private func parseNCXDocument(in container: Container, links: [Link]) async -> [String: [PublicationCollection]] {
        // Get the link in the readingOrder pointing to the NCX document.
        guard
            let ncxLink = links.firstWithMediaType(.ncx),
            let ncxURI = RelativeURL(string: ncxLink.href),
            let ncxDocumentData = try? await container.readData(at: ncxURI)
        else {
            return [:]
        }

        let ncx = NCXParser(data: ncxDocumentData, at: ncxURI)

        var collections: [String: [PublicationCollection]] = [:]
        func addCollection(_ type: NCXParser.NavType, role: String) {
            let links = ncx.links(for: type)
            if !links.isEmpty {
                collections[role] = [PublicationCollection(links: links)]
            }
        }

        addCollection(.tableOfContents, role: "toc")
        addCollection(.pageList, role: "pageList")

        return collections
    }

    /// Parse the mediaOverlays informations contained in the ressources then
    /// parse the associted SMIL files to populate the MediaOverlays objects
    /// in each of the ReadingOrder's Links.
    private func parseMediaOverlay(from container: Container, to publication: inout Publication) throws {
        // FIXME: For now we don't fill the media-overlays anymore, since it was only half implemented and the API will change
//        let mediaOverlays = publication.resources.filter(byType: .smil)
//
//        guard !mediaOverlays.isEmpty else {
//            log(.info, "No media-overlays found in the Publication.")
//            return
//        }
//        for mediaOverlayLink in mediaOverlays {
//            let node = MediaOverlayNode()
//
//            guard let smilData = try? fetcher.data(at: mediaOverlayLink.href),
//                let smilXml = try? XMLDocument(data: smilData) else
//            {
//                throw OPFParserError.invalidSmilResource
//            }
//
//            smilXml.definePrefix("smil", forNamespace: "http://www.w3.org/ns/SMIL")
//            smilXml.definePrefix("epub", forNamespace: "http://www.idpf.org/2007/ops")
//            guard let body = smilXml.firstChild(xpath: "./smil:body") else {
//                continue
//            }
//
//            node.role.append("section")
//            if let textRef = body.attr("textref") { // Prevent the crash on the japanese book
//                node.text = HREF(textRef, relativeTo: mediaOverlayLink.href).string
//            }
//            // get body parameters <par>a
//            let href = mediaOverlayLink.href
//            SMILParser.parseParameters(in: body, withParent: node, base: href)
//            SMILParser.parseSequences(in: body, withParent: node, publicationReadingOrder: &publication.readingOrder, base: href)
        // "/??/xhtml/mo-002.xhtml#mo-1" => "/??/xhtml/mo-002.xhtml"

//            guard let baseHref = node.text?.components(separatedBy: "#")[0],
//                let link = publication.readingOrder.first(where: { baseHref.contains($0.href) }) else
//            {
//                continue
//            }
//            link.mediaOverlays.append(node)
//            link.properties.mediaOverlay = EPUBConstant.mediaOverlayURL + link.href
//        }
    }
}
