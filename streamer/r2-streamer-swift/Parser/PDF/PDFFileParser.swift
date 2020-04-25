//
//  PDFFileParser.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 06.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import R2Shared


/// Structure holding the metadata from a standalone PDF file.
public struct PDFFileMetadata {
    
    // Permanent identifier based on the contents of the file at the time it was originally created.
    let identifier: String?
    
    // The version of the PDF specification to which the document conforms (for example, 1.4).
    let version: String?

    
    /// Values extracted from the document information dictionary, defined in PDF specification.

    // The document's title.
    let title: String?
    // The name of the person who created the document.
    let author: String?
    // The subject of the document.
    let subject: String?
    // Keywords associated with the document.
    let keywords: [String]
    // Outline to build the table of contents.
    let outline: [PDFOutlineNode]

}


public struct PDFOutlineNode {
    let title: String?
    let pageNumber: Int
    let children: [PDFOutlineNode]
}

extension Array where Element == PDFOutlineNode {
    
    func links(withHref href: String) -> [Link] {
        return map { node in
            return Link(
                href: "\(href)#page=\(node.pageNumber)",
                type: MediaType.pdf.string,
                title: node.title,
                children: node.children.links(withHref: href)
            )
        }
    }
    
}


/// Protocol to implement if you want to use a different PDF engine than the one provided with Readium 2 to parse the PDF's metadata.
/// Note: this is not used in the case of .lcpdf files, since the metadata are parsed from the manifest.json file.
public protocol PDFFileParser {
    
    /// Initializes the parser with the given PDF data stream.
    /// You must `open` and `close` the stream when needed.
    init(stream: SeekableInputStream) throws
    
    /// An optional object that will be stored in `PDFContainer.context` after parsing the `Publication`. You can reuse this object later to render the PDF with a custom navigator, for example. This is a way to avoid opening and parsing the PDF several time with a custom PDF engine.
    var context: Any? { get }
    
    /// Renders the PDF's first page.
    func renderCover() throws -> UIImage?
    
    /// Parses the number of pages in the PDF.
    func parseNumberOfPages() throws -> Int

    /// Parses the PDF file metadata.
    func parseMetadata() throws -> PDFFileMetadata

}

extension PDFFileParser {
    
    var context: Any? { return nil }
    
}
