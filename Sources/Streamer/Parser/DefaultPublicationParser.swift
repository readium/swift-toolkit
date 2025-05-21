//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Default implementation of ``PublicationParser`` handling all the
/// publication formats supported by Readium.
public final class DefaultPublicationParser: CompositePublicationParser {
    public init(
        httpClient: HTTPClient,
        assetRetriever: AssetRetriever,
        pdfFactory: PDFDocumentFactory,
        additionalParsers: [PublicationParser] = []
    ) {
        super.init(additionalParsers + Array(ofNotNil:
            EPUBParser(),
            PDFParser(pdfFactory: pdfFactory),
            ReadiumWebPubParser(pdfFactory: pdfFactory, httpClient: httpClient),
            ImageParser(assetRetriever: assetRetriever),
            AudioParser(assetRetriever: assetRetriever)))
    }
}
