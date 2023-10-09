//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

public enum CBZParserError: Error {
    case invalidCBZ(path: String)
}

@available(*, unavailable, renamed: "CBZParserError")
public typealias CbzParserError = CBZParserError

/// CBZ publication parsing class.
@available(*, unavailable, message: "Use `ImageParser` instead")
public class CbzParser: PublicationParser {
    public func parse(asset: PublicationAsset, fetcher: Fetcher, warnings: WarningLogger?) throws -> Publication.Builder? {
        try ImageParser().parse(asset: asset, fetcher: fetcher, warnings: warnings)
    }
}
