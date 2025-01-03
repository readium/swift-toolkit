//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Parses a Publication from an asset.
public protocol PublicationParser {
    /// Constructs a ``Publication.Builder`` to build a ``Publication`` from a
    /// publication asset.
    ///
    /// - Parameters:
    ///   - asset: Publication asset.
    ///   - warnings: Used to report non-fatal parsing warnings, such as
    ///   publication authoring mistakes. This is useful to warn users of
    ///   potential rendering issues or help authors debug their publications.
    func parse(asset: Asset, warnings: WarningLogger?) async -> Result<Publication.Builder, PublicationParseError>
}

public enum PublicationParseError: Error {
    /// Asset format not supported.
    case formatNotSupported

    /// An error occurred while trying to read the asset.
    case reading(ReadError)
}
