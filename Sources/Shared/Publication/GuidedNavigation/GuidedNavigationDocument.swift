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
    /// A sequence of resources and/or media fragments into these resources,
    /// meant to be presented sequentially to the user.
    public var guided: [GuidedNavigationObject]

    public init(guided: [GuidedNavigationObject]) {
        self.guided = guided
    }

    public init?(json: JSONValue?, warnings: WarningLogger? = nil) throws {
        guard let jsonDict = JSONDictionary(json) else {
            if json == nil {
                return nil
            }
            warnings?.log("Invalid Guided Navigation Document", model: Self.self, source: json?.any, severity: .moderate)
            throw JSONError.parsing(Self.self)
        }
        let jsonObject = jsonDict.json

        let guided = [GuidedNavigationObject](json: jsonObject["guided"], warnings: warnings)
        guard !guided.isEmpty else {
            warnings?.log("Guided Navigation Document requires a non-empty guided array", model: Self.self, source: json?.any, severity: .moderate)
            throw JSONError.parsing(Self.self)
        }

        self.init(guided: guided)
    }

    public init?(json: Any?, warnings: WarningLogger? = nil) throws {
        try self.init(json: JSONValue(json), warnings: warnings)
    }
}
