//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// A composite ``PublicationParser`` which tries several parsers until it
/// finds one which supports the asset.
public class CompositePublicationParser: PublicationParser {
    private let parsers: [PublicationParser]

    public init(_ parsers: [PublicationParser]) {
        self.parsers = parsers
    }

    public convenience init(_ parsers: PublicationParser...) {
        self.init(parsers)
    }

    public func parse(asset: Asset, warnings: WarningLogger?) async -> Result<Publication.Builder, PublicationParseError> {
        for parser in parsers {
            let result = await parser.parse(asset: asset, warnings: warnings)
            if case let .failure(error) = result, case .formatNotSupported = error {
                continue
            }
            return result
        }

        return .failure(.formatNotSupported)
    }
}
