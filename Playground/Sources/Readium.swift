//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumAdapterGCDWebServer
import ReadiumShared
import ReadiumStreamer

@MainActor final class Readium {
    static let shared = Readium()

    lazy var httpClient: HTTPClient = DefaultHTTPClient()
    lazy var httpServer: HTTPServer = GCDHTTPServer(assetRetriever: assetRetriever)

    lazy var formatSniffer: FormatSniffer = DefaultFormatSniffer()

    lazy var assetRetriever = AssetRetriever(
        httpClient: httpClient
    )

    lazy var publicationOpener = PublicationOpener(
        parser: DefaultPublicationParser(
            httpClient: httpClient,
            assetRetriever: assetRetriever,
            pdfFactory: DefaultPDFDocumentFactory()
        )
    )

    private init() {}

    func open(file: FileURL) async throws(UserError) -> Publication {
        let asset = try await assetRetriever.retrieve(url: file)
            .mapError(\.userError)
            .get()

        return try await publicationOpener
            .open(
                asset: asset,
                allowUserInteraction: true
            )
            .mapError(\.userError)
            .get()
    }
}
