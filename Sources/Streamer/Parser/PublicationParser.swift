//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Parses a Publication from an asset.
public protocol PublicationParser {
    /// Constructs a `Publication.Builder` to build a `Publication` from a publication asset.
    ///
    /// - Parameters:
    ///   - asset: Digital medium (e.g. a file) used to access the publication.
    ///   - fetcher: Initial leaf fetcher which should be used to read the publication's resources.
    ///     This can be used to:
    ///       - support content protection technologies
    ///       - parse exploded archives or in archiving formats unknown to the parser, e.g. RAR
    ///     If the asset is not an archive, it will be reachable at the HREF /<asset.name>.
    ///   - warnings: Used to report non-fatal parsing warnings, such as publication authoring
    ///     mistakes. This is useful to warn users of potential rendering issues or help authors
    ///     debug their publications.
    func parse(asset: PublicationAsset, fetcher: Fetcher, warnings: WarningLogger?) throws -> Publication.Builder?
}
