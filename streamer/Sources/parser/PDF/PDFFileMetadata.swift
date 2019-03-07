//
//  PDFFileMetadata.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 06.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared


/// Structure holding the metadata from a standalone PDF file.
public struct PDFFileMetadata: Loggable {
    
    // Permanent identifier based on the contents of the file at the time it was originally created.
    let identifier: String?
    
    // The version of the PDF specification to which the document conforms (for example, 1.4)
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

}


/// Protocol to implement if you want to use a different PDF engine than the one provided with Readium 2 to parse the PDF's metadata.
public protocol PDFFileMetadataParser {
    
    /// Parses the PDF metadata from the given data stream.
    /// Note: this is not used in the case of .lcpdf files, since the metadata are parsed from the manifest.json file.
    ///
    /// - Parameter stream: Input stream to read the PDF data. You are responsible to open the stream before reading it and closing it when you're done.
    /// - Returns: A named tuple containing:
    ///   - `metadata` The parsed PDF file metadata
    //    - `context` An optional object that will be stored in `PDFContainer.context` after parsing the `Publication`. You can reuse this object later to render the PDF with a custom navigator, for example. The goal is to avoid opening and parsing the PDF several time.
    func parse(from stream: SeekableInputStream) throws -> (metadata: PDFFileMetadata, context: Any?)
    
}
