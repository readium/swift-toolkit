//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// `Publication` and the associated `Container`.
@available(*, unavailable, message: "Use an instance of `Streamer` to open a `Publication`")
public typealias PubBox = (publication: Publication, associatedContainer: Container)
/// A callback called when the publication license is loaded in the given DRM object.
@available(*, unavailable, message: "Use an instance of `Streamer` to open a `Publication`")
public typealias PubParsingCallback = (DRM?) throws -> Void

public extension PublicationParser {
    @available(*, unavailable, message: "Use an instance of `Streamer` to open a `Publication`")
    static func parse(fileAtPath path: String) throws -> (PubBox, PubParsingCallback) {
        fatalError("Not available")
    }
}

public extension Publication {
    @available(*, unavailable, message: "Use an instance of `Streamer` to parse a publication")
    static func parse(at url: URL) throws -> (PubBox, PubParsingCallback)? {
        fatalError("Not available")
    }
}
