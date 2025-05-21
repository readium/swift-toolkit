//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public enum OPDSParserError: Error {
    case documentNotFound
    case documentNotValid
}

public enum OPDSParser {
    static var feedURL: URL?

    /// Parse an OPDS feed or publication.
    /// Feed can be v1 (XML) or v2 (JSON).
    /// - parameter url: The feed URL
    public static func parseURL(url: URL, completion: @escaping (ParseData?, Error?) -> Void) {
        feedURL = url

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, let response = response else {
                completion(nil, error ?? OPDSParserError.documentNotFound)
                return
            }

            // We try to parse as an OPDS v1 feed,
            // then, if it fails, we try as an OPDS v2 feed.
            if let parseData = try? OPDS1Parser.parse(xmlData: data, url: url, response: response) {
                completion(parseData, nil)
            } else if let parseData = try? OPDS2Parser.parse(jsonData: data, url: url, response: response) {
                completion(parseData, nil)
            } else {
                // Not a valid OPDS ressource
                completion(nil, OPDSParserError.documentNotValid)
            }
        }.resume()
    }
}
