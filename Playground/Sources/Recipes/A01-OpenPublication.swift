//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import ReadiumStreamer

/// The result of opening a publication: the parsed `Publication` model and its
/// detected format.
///
/// `format` identifies the publication type (EPUB, PDF, audiobook, etc.).
/// You may persist `format.mediaType` in your bookshelf database and pass it
/// back to `AssetRetriever.retrieve(url:mediaType:)` to skip format detection
/// on re-open.
struct OpenedPublication {
    let publication: Publication
    let format: Format
}

/// Opens a publication file.
func openPublication(at url: AbsoluteURL) async throws -> OpenedPublication {
    // MARK: 1. Setup dependencies

    // An HTTP client is required even for local files because some publications
    // reference remote resources.
    let httpClient = DefaultHTTPClient()

    // The AssetRetriever provides read access to the content of a file and
    // sniffs its format. It takes an HTTP client because it supports file
    // served on a remote HTTP server.
    let assetRetriever = AssetRetriever(httpClient: httpClient)

    // The PublicationOpener parses an Asset into a full Publication object.
    let publicationOpener = PublicationOpener(
        // DefaultPublicationParser handles all the formats supported by Readium
        // out of the box (EPUB, PDF, audiobooks, etc.).
        parser: DefaultPublicationParser(
            httpClient: httpClient,
            assetRetriever: assetRetriever,
            pdfFactory: DefaultPDFDocumentFactory()
        )
    )

    // MARK: 2. Opens the file and sniffs its format.

    let asset = try await assetRetriever
        .retrieve(url: url)
        .get()

    // MARK: 3. Parse the asset into a Publication model.

    // Set allowUserInteraction to false if you are opening the publication
    // from the background or in a batch, to prevent Readium from displaying a
    // user interface. For example, this is used with Content Protections
    // (e.g. LCP) to request credentials to unlock the publication.
    let publication = try await publicationOpener
        .open(asset: asset, allowUserInteraction: true)
        .get()

    return OpenedPublication(
        publication: publication,
        format: asset.format
    )
}
