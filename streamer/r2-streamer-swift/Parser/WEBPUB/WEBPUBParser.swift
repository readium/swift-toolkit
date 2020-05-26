//
//  WEBPUBParser.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 25.06.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

public enum WEBPUBParserError: Error {
    case invalidURL(String)
    case parseFailure(url: URL, Error)
}

/// Parser for Readium Web Publications.
public class WEBPUBParser: PublicationParser {
    
    public static func parse(at url: URL) throws -> (PubBox, PubParsingCallback) {
        guard url.scheme != nil, !url.isFileURL else {
            throw WEBPUBParserError.invalidURL(url.absoluteString)
        }
        
        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data)
            let publication = try Publication(json: json)
            publication.format = .webpub
            
            let container = HTTPContainer(
                baseURL: url.deletingLastPathComponent(),
                mimetype: publication.link(withRel: "self")?.type ?? MediaType.webpubManifest.string
            )
            
            func didLoadDRM(drm: DRM?) {
                container.drm = drm
            }
            
            return ((publication, container), didLoadDRM)
            
        } catch {
            throw WEBPUBParserError.parseFailure(url: url, error)
        }
    }

}
