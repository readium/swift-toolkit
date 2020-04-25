//
//  PDFContainer.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 07.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared


public protocol PDFContainer: Container {
    
    /// Optional PDF context returned by the `PDFFileMetadataParser`.
    /// Can be used to store a rendering context (eg. PDFDocument) during the parsing stage to avoid opening the PDF a second time with a custom navigator using a different PDF engine.
    var context: Any? { get set }

}


final class PDFFileContainer: FileContainer, PDFContainer {
    
    var context: Any?
    
    init?(path: String) {
        super.init(path: path, mimetype: MediaType.pdf.string)
    }
    
}


final class LCPDFContainer: ArchiveContainer, PDFContainer {
    
    var context: Any?
    
    init?(path: String) {
        super.init(path: path, mimetype: MediaType.lcpProtectedPDF.string)
    }
}
