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
        case EpubConstant.mimetype:
            self = .epub
        case EpubConstant.mimetypeOEBPS:
            self = .epub
        case CbzConstant.mimetype:
            self = .cbz
        case PDFConstant.mimetype:
            self = .pdf
        default:
            self = .unknown
        }
    }
    
    /// Find the type (epub/cbz for now) of the publication at url.
    ///
    /// - Parameter url: The location of the publication file.
    /// - Returns: The type associated to this publication.
    static func getForPublication(at url: URL) -> PublicationType {
        let fileName = url.lastPathComponent
        let fileType = fileName.contains(".") ? fileName.components(separatedBy: ".").last : ""
        var publicationType = PublicationType.unknown
        
        // If directory.
        if fileType!.isEmpty {
            let mimetypePath = url.appendingPathComponent("mimetype").path
            publicationType = PublicationType(mimetype: try? String(contentsOfFile: mimetypePath, encoding: String.Encoding.utf8))
        } else /* Determine type with file extension */ {
            publicationType = PublicationType(rawValue: fileType!) ?? PublicationType.unknown
        }
        return publicationType
    }
}
