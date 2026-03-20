//
//  Copyright 2026 Readium Foundation. All rights reserved.
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

    public func parse(asset: Asset, warnings: WarningLogger?) async throws(PublicationParseError) -> Publication.Builder {
        for parser in parsers {
            do {
                return try await parser.parse(asset: asset, warnings: warnings)
            } catch {
                switch error {
                case .formatNotSupported:
                    continue
                case .reading:
                    throw error
                }
            }
        }

        throw .formatNotSupported
    }
}
