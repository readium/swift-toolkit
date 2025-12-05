//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Holds information about an LCP protected publication which was acquired
/// from an LCPL.
public struct LCPAcquiredPublication {
    /// Path to the downloaded publication.
    ///
    /// You must move this file to the user library's folder.
    public let localURL: FileURL

    /// Format of the downloaded file.
    public let format: Format

    /// Filename that should be used for the publication when importing it in
    /// the user library.
    public let suggestedFilename: String

    /// LCP license document.
    public let licenseDocument: LicenseDocument
}
