//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import PDFKit
import ReadiumShared

/// `ResourceContentExtractor` implementation for PDF resources.
///
/// Extracts the plain text content of a PDF resource by concatenating the text
/// of each page using PDFKit.
class PDFResourceContentExtractor: ResourceContentExtractor {
    func extractText(of resource: Resource) async -> ReadResult<String> {
        let result = await resource.read()
        switch result {
        case let .success(data):
            guard let pdfDocument = PDFKit.PDFDocument(data: data) else {
                return .failure(.decoding(PDFResourceContentExtractorError.openFailed))
            }

            let text = (0 ..< pdfDocument.pageCount)
                .compactMap { pdfDocument.page(at: $0)?.string }
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "\n\n")

            return .success(text)

        case let .failure(error):
            return .failure(error)
        }
    }
}

/// `ResourceContentExtractorFactory` that produces a `PDFResourceContentExtractor`
/// for PDF media types.
public class PDFResourceContentExtractorFactory: ResourceContentExtractorFactory {
    public init() {}

    public func makeExtractor(for resource: Resource, mediaType: MediaType) -> ResourceContentExtractor? {
        guard mediaType == .pdf else {
            return nil
        }
        return PDFResourceContentExtractor()
    }
}

private enum PDFResourceContentExtractorError: Error {
    case openFailed
}
