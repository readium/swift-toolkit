//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Indicated the availability of a given resource.
/// https://drafts.opds.io/schema/properties.schema.json
public struct OPDSAvailability: Equatable, JSONValueDecodable, JSONObjectEncodable {
    public let state: State

    /// Timestamp for the previous state change.
    public let since: Date?

    /// Timestamp for the next state change.
    public let until: Date?

    public init(state: State, since: Date? = nil, until: Date? = nil) {
        self.state = state
        self.since = since
        self.until = until
    }

    public init?(json: JSONValue?, warnings: WarningLogger? = nil) throws {
        guard let json = json else {
            return nil
        }
        guard let jsonObject = json.object,
              let state: State = jsonObject["state"]?.parseRaw()
        else {
            warnings?.log("`state` is required", model: Self.self, source: json.any)
            throw JSONError.parsing(Self.self)
        }

        self.init(
            state: state,
            since: jsonObject["since"]?.parseDate(),
            until: jsonObject["until"]?.parseDate()
        )
    }

    public var jsonObject: [String: JSONValue] {
        .init([
            "state": state.rawValue,
            "since": since?.iso8601,
            "until": until?.iso8601,
        ])
    }

    public enum State: String {
        case available, unavailable, reserved, ready
    }
}
