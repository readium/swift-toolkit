//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Event related to the change in status of a License Document.
public struct Event: Sendable {
    public enum EventType: String {
        /// Signals a successful registration event by a device.
        case register
        /// Signals a successful renew event.
        case renew
        /// Signals a successful return event.
        case `return`
        /// Signals a revocation event.
        case revoke
        /// Signals a cancellation event.
        case cancel
    }

    /// Identifies the type of event.
    /// Note: we don't use an enum here in case a LSD server extends the event types.
    public let type: String
    /// Name of the client, as provided by the client during an interaction.
    public let name: String
    /// Identifies the client, as provided by the client during an interaction.
    public let id: String
    /// Time and date when the event occurred.
    public let date: Date // Named timestamp in spec.

    init?(json: JSONValue?) {
        guard let json = JSONDictionary(json),
              let type = json["type"]?.string,
              let name = json["name"]?.string,
              let id = json["id"]?.string,
              let date = parseDate(json["timestamp"])
        else {
            return nil
        }
        self.type = type
        self.name = name
        self.id = id
        self.date = date
    }

    init?(json: [String: Any]) {
        self.init(json: JSONValue(json))
    }
}
