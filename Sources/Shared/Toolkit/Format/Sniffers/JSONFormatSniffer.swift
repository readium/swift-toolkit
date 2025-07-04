//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Sniffs a JSON document.
public struct JSONFormatSniffer: FormatSniffer {
    public init() {}

    public func sniffHints(_ hints: FormatHints) -> Format? {
        if
            hints.hasFileExtension("json") ||
            hints.hasMediaType("application/json")
        {
            return json
        }

        if
            hints.hasMediaType("application/problem+json")
        {
            return jsonProblemDetails
        }

        return nil
    }

    public func sniffBlob(_ blob: FormatSnifferBlob, refining format: Format) async -> ReadResult<Format?> {
        await blob.readAsJSON()
            .map {
                guard $0 != nil else {
                    return nil
                }
                return json
            }
    }

    private let json = Format(
        specifications: .json,
        mediaType: .json,
        fileExtension: "json"
    )

    private let jsonProblemDetails = Format(
        specifications: .json, .problemDetails,
        mediaType: .json,
        fileExtension: "json"
    )
}
