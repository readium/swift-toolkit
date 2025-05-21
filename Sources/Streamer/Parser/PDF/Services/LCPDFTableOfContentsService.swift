//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import ReadiumShared

/// This ``TableOfContentsService`` will load the table of contents of the
/// single PDF resource in an LCPDF package, if the table of contents is missing
/// from the `manifest.json` file.
final class LCPDFTableOfContentsService: TableOfContentsService, PDFPublicationService, Loggable {
    private let manifest: Manifest
    private let container: Container
    var pdfFactory: PDFDocumentFactory

    init(
        manifest: Manifest,
        container: Container,
        pdfFactory: PDFDocumentFactory
    ) {
        self.manifest = manifest
        self.container = container
        self.pdfFactory = pdfFactory
    }

    func tableOfContents() async -> ReadResult<[Link]> {
        await tableOfContentsTask.value
    }

    private lazy var tableOfContentsTask: Task<ReadResult<[Link]>, Never> = Task {
        guard
            manifest.tableOfContents.isEmpty,
            manifest.readingOrder.count == 1,
            let url = manifest.readingOrder.first?.url(),
            let resource = container[url]
        else {
            return .success(manifest.tableOfContents)
        }

        do {
            let toc = try await pdfFactory.open(resource: resource, at: url, password: nil).tableOfContents()
            return .success(toc.linksWithDocumentHREF(url))
        } catch {
            return .failure(.decoding(error))
        }
    }

    static func makeFactory(pdfFactory: PDFDocumentFactory) -> (PublicationServiceContext) -> LCPDFTableOfContentsService? {
        { context in
            LCPDFTableOfContentsService(
                manifest: context.manifest,
                container: context.container,
                pdfFactory: pdfFactory
            )
        }
    }
}
