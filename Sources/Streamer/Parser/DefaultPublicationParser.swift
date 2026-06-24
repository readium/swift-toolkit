//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Default implementation of ``PublicationParser`` handling all the
/// publication formats supported by Readium.
public final class DefaultPublicationParser: PublicationParser {
    private let parser: CompositePublicationParser

    public init(
        httpClient: HTTPClient,
        assetRetriever: AssetRetriever,
        pdfFactory: PDFDocumentFactory,
        additionalParsers: [PublicationParser] = []
    ) {
        parser = CompositePublicationParser(additionalParsers + [
            EPUBParser(),
            PDFParser(pdfFactory: pdfFactory),
            ReadiumWebPubParser(pdfFactory: pdfFactory, httpClient: httpClient),
            ImageParser(assetRetriever: assetRetriever),
            AudioParser(assetRetriever: assetRetriever),
        ])
    }

    public func parse(
        asset: Asset,
        warnings: WarningLogger?
    ) async -> Result<Publication.Builder, PublicationParseError> {
        await parser.parse(asset: asset, warnings: warnings)
    }
}
