//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import PDFKit
import ReadiumShared

final class PDFDocumentHolder {
    private var href: AnyURL?
    private var document: PDFKit.PDFDocument?

    func set<HREF: URLConvertible>(_ document: PDFKit.PDFDocument, at href: HREF) {
        self.href = href.anyURL
        self.document = document
    }
}

extension PDFDocumentHolder: ReadiumShared.PDFDocumentFactory {
    func open(file: FileURL, password: String?) throws -> ReadiumShared.PDFDocument {
        guard let document = document, file.anyURL == href else {
            throw PDFDocumentError.openFailed
        }
        return document
    }

    public func open<HREF: URLConvertible>(resource: Resource, at href: HREF, password: String?) async throws -> ReadiumShared.PDFDocument {
        guard let document = document, self.href == href.anyURL else {
            throw PDFDocumentError.openFailed
        }
        return document
    }
}
