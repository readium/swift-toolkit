//
//  OPDSParser.swift
//  readium-opds
//
//  Created by Geoffrey Bugniot on 22/05/2018.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

public enum OPDSParserError: Error {
    case documentNotFound
    case documentNotValid
}

public class OPDSParser {
    
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

#if compiler(>=5.5) && canImport(_Concurrency)

    /// Asynchronously Parse an OPDS feed or publication.
    /// Feed can be v1 (XML) or v2 (JSON).
    /// - parameter url: The feed URL
    @available(iOS 13.0, *)
    public static func parseURL(url: URL) async throws -> ParseData {
        try await withCheckedThrowingContinuation { continuation in
            parseURL(url: url) { data, error in
                if let error = error {
                    continuation.resume(with: .failure(error))
                } else if let data = data {
                    continuation.resume(with: .success(data))
                } else {
                    continuation.resume(with: .failure(OPDSParserError.documentNotValid))
                }
            }
        }
    }

#endif

}
