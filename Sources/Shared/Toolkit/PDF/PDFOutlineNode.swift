//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public struct PDFOutlineNode {
    /// Title of this outline item.
    public let title: String?

    /// Page number of this outline item, starting from 1.
    public let pageNumber: Int

    /// Children of this item, if it's not a leaf.
    public let children: [PDFOutlineNode]

    public init(title: String?, pageNumber: Int, children: [PDFOutlineNode]) {
        self.title = title
        self.pageNumber = pageNumber
        self.children = children
    }

    /// Converts a PDF outline node and its descendants to a `Link` object.
    ///
    /// - Parameter href: HREF of the PDF document in the `Publication` to
    /// which the links are relative to.
    public func linkWithDocumentHREF<T: URLConvertible>(_ href: T) -> Link {
        Link(
            href: "\(href.anyURL.string)#page=\(pageNumber)",
            mediaType: .pdf,
            title: title,
            children: children.linksWithDocumentHREF(href)
        )
    }
}

public extension Sequence where Element == PDFOutlineNode {
    /// Converts a list of PDF outline node and their descendants to `Link` objects.
    ///
    /// - Parameter href: HREF of the PDF document in the `Publication` to
    /// which the links are relative to.
    func linksWithDocumentHREF<T: URLConvertible>(_ href: T) -> [Link] {
        map { $0.linkWithDocumentHREF(href) }
    }
}
