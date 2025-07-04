//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Sniffs an LCP License Document.
public struct LCPLicenseFormatSniffer: FormatSniffer {
    public init() {}

    public func sniffHints(_ hints: FormatHints) -> Format? {
        if
            hints.hasFileExtension("lcpl") ||
            hints.hasMediaType("application/vnd.readium.lcp.license.v1.0+json")
        {
            return lcpLicense
        }

        return nil
    }

    public func sniffBlob(_ blob: FormatSnifferBlob, refining format: Format) async -> ReadResult<Format?> {
        guard format.conformsTo(.json) else {
            return .success(nil)
        }

        return await blob.readAsJSON()
            .map {
                guard
                    let json = $0 as? [String: Any],
                    Set(json.keys).isSuperset(of: ["id", "issued", "provider", "encryption"])
                else {
                    return nil
                }
                return lcpLicense
            }
    }

    private let lcpLicense = Format(
        specifications: .json, .lcpLicense,
        mediaType: .lcpLicenseDocument,
        fileExtension: "lcpl"
    )
}
