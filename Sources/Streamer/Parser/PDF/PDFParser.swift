//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreGraphics
import Foundation
import ReadiumShared

public final class PDFParser: PublicationParser, Loggable {
    private let pdfFactory: PDFDocumentFactory

    public init(pdfFactory: PDFDocumentFactory) {
        self.pdfFactory = pdfFactory
    }

    public func parse(
        asset: Asset,
        warnings: WarningLogger?
    ) async -> Result<Publication.Builder, PublicationParseError> {
        guard
            asset.format.conformsTo(.pdf),
            case let .resource(asset) = asset
        else {
            return .failure(.formatNotSupported)
        }

        do {
            let container = SingleResourceContainer(publication: asset)
            let href = container.entry
            let resource = asset.resource
            let document = try await pdfFactory.open(resource: resource, at: href, password: nil)
            let authors = try await Array(ofNotNil: document.author().map { Contributor(name: $0) })

            return try await .success(
                Publication.Builder(
                    manifest: Manifest(
                        metadata: Metadata(
                            identifier: document.identifier(),
                            conformsTo: [.pdf],
                            title: document.title(),
                            authors: authors,
                            readingProgression: document.readingProgression() ?? .auto,
                            numberOfPages: document.pageCount()
                        ),
                        readingOrder: [
                            Link(
                                href: href.string,
                                mediaType: .pdf
                            ),
                        ],
                        tableOfContents: document.tableOfContents().linksWithDocumentHREF(href)
                    ),
                    container: container,
                    servicesBuilder: PublicationServicesBuilder(
                        content: DefaultContentService.makeFactory(
                            resourceContentIteratorFactories: [
                                PDFResourceContentIterator.Factory(),
                            ]
                        ),
                        cover: document.cover().map(GeneratedCoverService.makeFactory(cover:)),
                        positions: PDFPositionsService.makeFactory(),
                        search: ContentSearchService.makeFactory(),
                        setup: {
                            $0.setPDFDocumentServiceFactory(
                                DefaultPDFDocumentService.makeFactory(
                                    factory: pdfFactory,
                                    cached: (href: href, document: document)
                                )
                            )
                        }
                    )
                )
            )
        } catch let PDFDocumentError.reading(error) {
            return .failure(.reading(error))
        } catch {
            return .failure(.reading(.wrap(error) ?? .decoding(error)))
        }
    }
}
