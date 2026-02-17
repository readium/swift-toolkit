//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Represents a Guided Navigation Document, as defined in the
/// Readium Guided Navigation specification.
///
/// https://readium.org/guided-navigation/
public struct GuidedNavigationDocument: Hashable, Sendable {
    /// References to other resources that are related to the current Guided
    /// Navigation Document.
    public var links: [Link]

    /// A sequence of resources and/or media fragments into these resources,
    /// meant to be presented sequentially to the user.
    public var guided: [GuidedNavigationObject]

    public init(
        links: [Link] = [],
        guided: [GuidedNavigationObject]
    ) {
        self.links = links
        self.guided = guided
    }

    public init?(json: Any?, warnings: WarningLogger? = nil) throws {
        guard let json = json as? [String: Any] else {
            if json == nil {
                return nil
            }
            warnings?.log("Invalid Guided Navigation Document", model: Self.self, source: json, severity: .moderate)
            throw JSONError.parsing(Self.self)
        }

        let guided = try [GuidedNavigationObject](json: json["guided"], warnings: warnings)
        guard !guided.isEmpty else {
            warnings?.log("Guided Navigation Document requires a non-empty guided array", model: Self.self, source: json, severity: .moderate)
            throw JSONError.parsing(Self.self)
        }

        self.init(
            links: [Link](json: json["links"], warnings: warnings),
            guided: guided
        )
    }
}
