//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import ReadiumShared

/// Loads the table of contents of the single PDF resource in an LCPDF package,
/// when the table of contents is missing from the `manifest.json` file.
///
/// Requires the publication to have a ``PDFDocumentService``.
final class LCPDFTableOfContentsService: TableOfContentsService, Loggable {
    private let manifest: Manifest
    private let publication: Weak<Publication>

    init(
        manifest: Manifest,
        publication: Weak<Publication>
    ) {
        self.manifest = manifest
        self.publication = publication
    }

    func tableOfContents() async -> ReadResult<[Link]> {
        await cache.getOrMakeTask(
            manifest: manifest,
            container: container,
            pdfFactory: pdfFactory
        ).value
    }

    private actor Cache {
        var task: Task<ReadResult<[Link]>, Never>?

        func getOrMakeTask(
            manifest: Manifest,
            container: Container,
            pdfFactory: PDFDocumentFactory
        ) -> Task<ReadResult<[Link]>, Never> {
            if let task = task {
                return task
            }

            let newTask = Task<ReadResult<[Link]>, Never> {
                guard
                    manifest.tableOfContents.isEmpty,
                    manifest.readingOrder.count == 1,
                    let url = manifest.readingOrder.first?.url()
                else {
                    return .success(manifest.tableOfContents)
                }
                guard let pdfDocumentService = publication.ref?.pdfDocumentService else {
                    return .failure(.unsupportedOperation(DebugError("PDFDocumentService is required to use the LCPDFTableOfContentsService")))
                }

                do {
                    let toc = try await pdfDocumentService.openDocument(at: url).tableOfContents()
                    return .success(toc.linksWithDocumentHREF(url))
                } catch {
                    return .failure(.wrap(error) ?? .decoding(error))
                }
            }

            task = newTask
            return newTask
        }
    }

    private let cache = Cache()

        static func makeFactory() -> (PublicationServiceContext) -> LCPDFTableOfContentsService? {
        { context in
            LCPDFTableOfContentsService(
                manifest: context.manifest,
                publication: context.publication
            )
        }
    }
}
