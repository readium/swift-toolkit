//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreGraphics
import Foundation
import ReadiumShared

/// Errors thrown during the parsing of the PDF.
public enum PDFParserError: Error {
    // The file at 'path' is missing from the container.
    case missingFile(path: String)
    // Failed to open the PDF
    case openFailed
    // The PDF is encrypted with a password. This is not supported right now.
    case fileEncryptedWithPassword
    // The LCP for PDF Package is malformed.
    case invalidLCPDF
}

public final class PDFParser: PublicationParser, Loggable {
    enum Error: Swift.Error {
        case fileNotReadable
    }

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
            let resource = asset.resource
            let document = try await pdfFactory.open(resource: resource, at: container.entry, password: nil)
            let authors = try await Array(ofNotNil: document.author().map { Contributor(name: $0) })

            return try await .success(Publication.Builder(
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
                            href: container.entry.string,
                            mediaType: .pdf
                        ),
                    ],
                    tableOfContents: document.tableOfContents().linksWithDocumentHREF(container.entry)
                ),
                container: container,
                servicesBuilder: PublicationServicesBuilder(
                    cover: document.cover().map(GeneratedCoverService.makeFactory(cover:)),
                    positions: PDFPositionsService.makeFactory()
                )
            ))
        } catch {
            return .failure(.reading(.decoding(error)))
        }
    }
}
