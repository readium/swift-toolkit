//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import PDFKit
import ReadiumShared

final class PDFDocumentHolder {
    private var href: String?
    private var document: PDFKit.PDFDocument?

    func set(_ document: PDFKit.PDFDocument, at href: String) {
        self.href = href
        self.document = document
    }
}

extension PDFDocumentHolder: ReadiumShared.PDFDocumentFactory {
    func open(file: FileURL, password: String?) throws -> ReadiumShared.PDFDocument {
        guard let document = document, file.string == href else {
            throw PDFDocumentError.openFailed
        }
        return document
    }

    func open(resource: Resource, password: String?) throws -> ReadiumShared.PDFDocument {
        guard let document = document, resource.link.href == href else {
            throw PDFDocumentError.openFailed
        }
        return document
    }
}
