//
//  PDFOutlineNode.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 21/09/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

public struct PDFOutlineNode {
    
    /// Title of this outline item.
    public let title: String?
    
    /// Page number of this outline item, starting from 1.
    public let pageNumber: Int
    
    /// Children of this item, if it's not a leaf.
    public let children: [PDFOutlineNode]
    
    /// Converts a PDF outline node and its descendants to a `Link` object.
    ///
    /// - Parameter documentHref: HREF of the PDF document in the `Publication` to which the links
    ///   are relative to.
    public func link(withDocumentHREF documentHREF: String) -> Link {
        Link(
            href: "\(documentHREF)#page=\(pageNumber)",
            type: MediaType.pdf.string,
            title: title,
            children: children.links(withDocumentHREF: documentHREF)
        )
    }

}

extension Sequence where Element == PDFOutlineNode {
    
    /// Converts a list of PDF outline node and their descendants to `Link` objects.
    ///
    /// - Parameter documentHref: HREF of the PDF document in the `Publication` to which the links
    ///   are relative to.
    public func links(withDocumentHREF documentHREF: String) -> [Link] {
        map { $0.link(withDocumentHREF: documentHREF) }
    }
    
}
