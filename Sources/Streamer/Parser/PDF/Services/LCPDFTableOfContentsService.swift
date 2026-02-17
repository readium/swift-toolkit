//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import ReadiumShared

/// This ``TableOfContentsService`` will load the table of contents of the
/// single PDF resource in an LCPDF package, if the table of contents is missing
/// from the `manifest.json` file.
final class LCPDFTableOfContentsService: TableOfContentsService, PDFPublicationService, Loggable, @unchecked Sendable {
    private let manifest: Manifest
    private let container: Container
    var pdfFactory: PDFDocumentFactory

    private let tableOfContentsTask: Task<ReadResult<[Link]>, Never>

    init(
        manifest: Manifest,
        container: Container,
        pdfFactory: PDFDocumentFactory
    ) {
        self.manifest = manifest
        self.container = container
        self.pdfFactory = pdfFactory

        struct Captures: Sendable {
            let manifest: Manifest
            let container: Container
            let pdfFactory: PDFDocumentFactory
        }
        let captures = Captures(manifest: manifest, container: container, pdfFactory: pdfFactory)

        tableOfContentsTask = Task {
            let manifest = captures.manifest
            let container = captures.container
            let pdfFactory = captures.pdfFactory

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
    }

    func tableOfContents() async -> ReadResult<[Link]> {
        await tableOfContentsTask.value
    }

    static func makeFactory(pdfFactory: PDFDocumentFactory) -> @Sendable (PublicationServiceContext) -> LCPDFTableOfContentsService? {
        struct Captures: Sendable {
            let pdfFactory: PDFDocumentFactory
        }
        let captures = Captures(pdfFactory: pdfFactory)

        return { context in
            LCPDFTableOfContentsService(
                manifest: context.manifest,
                container: context.container,
                pdfFactory: captures.pdfFactory
            )
        }
    }
}
