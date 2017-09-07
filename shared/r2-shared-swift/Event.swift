//
//  Event.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 9/6/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import SwiftyJSON

/// Event related to the change in status of a License Document.
public struct Event {
    /// Identifies the type of event.
    public var type: Int // Type TODO
    /// Name of the client, as provided by the client during an interaction.
    public var name: String
    /// Identifies the client, as provided by the client during an interaction.
    public var id: String
    /// Time and date when the event occurred.
    public var date: Date // Named timestamp in spec.

    /// Describe the type of the Event.
    ///
    /// - register: Associate a new device with the License.
    /// - `return`: Ask for the License to be immediately invalidated.
    /// - renew: Extends the expiration date of a license into the future.
//    public enum Type { //TODO
//        case register
//        case `return`
//        case renew
//    }

    public init(with json: JSON) throws {
        guard let name = json["name"].string,
            let dateData = json["timestamp"].string,
            let type = json["type"].int,
            let id = json["id"].string else
        {
            throw LsdError.json
        }
        guard let date = dateData.dateFromISO8601 else {
            throw LsdError.date
        }
        self.type = type
        self.name = name
        self.id = id
        self.date = date
    }
}
