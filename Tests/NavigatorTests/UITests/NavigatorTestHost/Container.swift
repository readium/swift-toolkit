//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumAdapterGCDWebServer
import ReadiumNavigator
import ReadiumShared
import ReadiumStreamer
import UIKit

/// Shared Readium infrastructure for testing.
@MainActor class Container {
    static let shared = Container()

    let memoryTracker = MemoryTracker()
    let httpClient: HTTPClient
    let httpServer: HTTPServer
    let assetRetriever: AssetRetriever
    let publicationOpener: PublicationOpener

    init() {
        httpClient = DefaultHTTPClient()
        assetRetriever = AssetRetriever(httpClient: httpClient)
        httpServer = GCDHTTPServer(assetRetriever: assetRetriever)

        publicationOpener = PublicationOpener(
            parser: DefaultPublicationParser(
                httpClient: httpClient,
                assetRetriever: assetRetriever,
                pdfFactory: DefaultPDFDocumentFactory()
            ),
            contentProtections: []
        )
    }

    func publication(at url: FileURL) async throws -> Publication {
        let asset = try await assetRetriever.retrieve(url: url).get()
        let publication = try await publicationOpener.open(
            asset: asset,
            allowUserInteraction: false,
            sender: nil
        ).get()

        memoryTracker.track(publication)
        return publication
    }

    func navigator(for publication: Publication) throws -> VisualNavigator & UIViewController {
        if publication.conforms(to: .epub) {
            return try epubNavigator(for: publication)
        } else if publication.conforms(to: .pdf) {
            return try pdfNavigator(for: publication)
        } else {
            fatalError("Publication not supported")
        }
    }

    func epubNavigator(for publication: Publication) throws -> EPUBNavigatorViewController {
        let navigator = try EPUBNavigatorViewController(
            publication: publication,
            initialLocation: nil,
            config: EPUBNavigatorViewController.Configuration(),
            httpServer: httpServer
        )
        memoryTracker.track(navigator)
        return navigator
    }

    func pdfNavigator(for publication: Publication) throws -> PDFNavigatorViewController {
        let navigator = try PDFNavigatorViewController(
            publication: publication,
            initialLocation: nil,
            httpServer: httpServer
        )
        memoryTracker.track(navigator)
        return navigator
    }
}
