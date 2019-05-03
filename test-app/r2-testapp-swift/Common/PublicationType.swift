//
//  PublicationType.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 22.02.19.
//
//  Copyright 2019 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import CoreServices
import Foundation
import R2Streamer

enum PublicationType: String {
    
    case cbz = "cbz"
    case epub = "epub"
    case pdf = "pdf"
    case unknown = "unknown"
    
    init(rawString: String?) {
        self = PublicationType(rawValue: rawString ?? "") ?? .unknown
    }
    
    init(mimetype: String?) {
        switch mimetype {
        case EpubConstant.mimetype, EpubConstant.mimetypeOEBPS:
            self = .epub
        case CbzConstant.mimetype:
            self = .cbz
        case PDFConstant.pdfMimetype, PDFConstant.lcpdfMimetype:
            self = .pdf
        default:
            self = .unknown
        }
    }
    
    /// Finds the type of the publication at url.
    init(url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            self = .unknown
            return
        }
        
        var mimetype: String?
        if isDirectory.boolValue {
            mimetype = try? String(contentsOf: url.appendingPathComponent("mimetype"), encoding: String.Encoding.utf8)
        } else if let extUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, url.pathExtension as CFString, nil)?.takeUnretainedValue() {
            mimetype = UTTypeCopyPreferredTagWithClass(extUTI, kUTTagClassMIMEType)?.takeRetainedValue() as String?
        }
        
        guard let unwrappedMimetype = mimetype else {
            self = .unknown
            return
        }
        
        self.init(mimetype: unwrappedMimetype)
    }
    
}
