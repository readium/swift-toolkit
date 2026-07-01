//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public enum OPDSParserError: Error, Sendable {
    case documentNotFound
    case documentNotValid
}

public enum OPDSParser {
    /// Parse an OPDS feed or publication.
    /// Feed can be v1 (XML) or v2 (JSON).
    /// - Parameter url: The feed URL.
    /// - Returns: The parsed `ParseData`.
    /// - Throws: An error if the resource could not be fetched, or is not a valid OPDS resource.
    public static func parseURL(url: URL) async throws -> ParseData {
        let (data, response) = try await URLSession.shared.data(from: url)

        // We try to parse as an OPDS v1 feed,
        // then, if it fails, we try as an OPDS v2 feed.
        if let parseData = try? OPDS1Parser.parse(xmlData: data, url: url, response: response) {
            return parseData
        } else if let parseData = try? OPDS2Parser.parse(jsonData: data, url: url, response: response) {
            return parseData
        } else {
            // Not a valid OPDS ressource
            throw OPDSParserError.documentNotValid
        }
    }
}
