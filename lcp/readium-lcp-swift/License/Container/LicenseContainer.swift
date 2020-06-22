//
//  LicenseContainer.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 05.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

/// Encapsulates the read/write access to the packaged License Document (eg. in an EPUB container, or a standalone LCPL file)
protocol LicenseContainer {
    
    func read() throws -> Data
    func write(_ license: LicenseDocument) throws

}

func makeLicenseContainer(for publication: URL, mimetypes: [String] = []) throws -> LicenseContainer {
    guard let format = Format.of(publication, mediaTypes: mimetypes, fileExtensions: []) else {
        throw LCPError.licenseContainer(.openFailed)
    }

    switch format {
    case .lcpProtectedPDF, .lcpProtectedAudiobook, .readiumAudiobook, .readiumWebPub, .divina:
        return ReadiumLicenseContainer(path: publication)
    case .epub:
        return EPUBLicenseContainer(epub: publication)
    default:
        throw LCPError.licenseContainer(.openFailed)
    }
}
