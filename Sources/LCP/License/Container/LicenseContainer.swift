//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
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
    deferred(on: .global(qos: .background)) { success, _, _ in
        success(makeLicenseContainerSync(for: file, mimetypes: mimetypes))
    }
}

func makeLicenseContainerSync(for file: URL, mimetypes: [String] = []) -> LicenseContainer? {
    guard let mediaType = MediaType.of(file, mediaTypes: mimetypes, fileExtensions: []) else {
        return nil
    }

    switch mediaType {
    case .lcpLicenseDocument:
        return LCPLLicenseContainer(lcpl: file)
    case .lcpProtectedPDF, .lcpProtectedAudiobook, .readiumAudiobook, .readiumWebPub, .divina:
        return ReadiumLicenseContainer(path: file)
    case .epub:
        return EPUBLicenseContainer(epub: file)
    default:
        return nil
    }
}
