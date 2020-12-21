//
//  CBZParser.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri on 3/31/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

public enum CBZParserError: Error {
    case invalidCBZ(path: String)
}

@available(*, deprecated, renamed: "CBZParserError")
public typealias CbzParserError = CBZParserError

/// CBZ publication parsing class.
@available(*, unavailable, message: "Use `ImageParser` instead")
public class CbzParser: PublicationParser {
    
    public func parse(asset: PublicationAsset, fetcher: Fetcher, warnings: WarningLogger?) throws -> Publication.Builder? {
        return try ImageParser().parse(asset: asset, fetcher: fetcher, warnings: warnings)
    }

}
