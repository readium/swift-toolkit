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
    
    /// Returns whether this container currently contains a License Document.
    ///
    /// For example, when fulfilling an EPUB publication, it initially doesn't contain the license.
    func containsLicense() -> Bool
    
    func read() throws -> Data
    func write(_ license: LicenseDocument) throws

}

func makeLicenseContainer(for file: URL, mimetypes: [String] = []) -> Deferred<LicenseContainer?, LCPError> {
    return deferred(on: .global(qos: .background)) { success, _, _ in
        guard let format = Format.of(file, mediaTypes: mimetypes, fileExtensions: []) else {
            success(nil)
            return
        }

        switch format {
        case .lcpLicense:
            success(LCPLLicenseContainer(lcpl: file))
        case .lcpProtectedPDF, .lcpProtectedAudiobook, .readiumAudiobook, .readiumWebPub, .divina:
            success(ReadiumLicenseContainer(path: file))
        case .epub:
            success(EPUBLicenseContainer(epub: file))
        default:
            success(nil)
        }
    }
}
