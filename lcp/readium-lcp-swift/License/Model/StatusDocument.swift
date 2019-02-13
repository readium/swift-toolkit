//
//  StatusDocument.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/6/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import SwiftyJSON

/// Document that contains information about the history of a License Document,
/// along with its current status and available interactions.
class StatusDocument {
    var id: String
    var status: Status
    /// A message meant to be displayed to the User regarding the current status
    /// of the license.
    var message: String
    /// Must contain at least a link to the LicenseDocument associated to this.
    /// Status Document.
    var links = [Link]()

    var updated: Updated
    /// Dictionnary of potential rights associated with Dates.
    var potentialRights: PotentialRights?
    /// Ordered list of events related to the change in status of a License
    /// Document.
    var events: [Event]!

    /// Describes the status of the license.
    ///
    /// - ready: The License Document is available, but the user hasn't accessed
    ///          the License and/or Status Document yet.
    /// - active: The license is active, and a device has been successfully
    ///           registered for this license. This is the default value if the
    ///           License Document does not contain a registration link, or a
    ///           registration mechanism through the license itself.
    /// - revoked: The license is no longer active, it has been invalidated by
    ///            the Issuer.
    /// - returned: The license is no longer active, it has been invalidated by
    ///             the User.
    /// - cancelled: The license is no longer active because it was cancelled
    ///              prior to activation.
    /// - expired: The license is no longer active because it has expired.
    enum Status: String {
        case ready
        case active
        case revoked
        case returned
        case cancelled
        case expired
    }

    enum Rel: String {
        case register = "register"
        case license = "license"
        case `return` = "return"
        case renew = "renew"
    }

    init(data: Data) throws {
        let json = JSON(data: data)

        // Retrieves the non optional fields.
        guard let id = json["id"].string,
            let statusData = json["status"].string,
            let status = Status(rawValue: statusData),
            let message = json["message"].string else
        {
            throw ParsingError.json
        }
        self.id = id
        self.status = status
        self.message = message
        self.updated = try Updated.init(with: json["updated"])
        links = try parseLinks(json["links"])
        events = try parseEvents(json["events"])
        potentialRights = PotentialRights.init(with: json["potential_rights"])
    }

    /// Returns the first link containing the given rel.
    /// - Throws: `LCPError.linkNotFound` if no link is found with this rel.
    /// - Returns: The first link containing the rel.
    func link(withRel rel: Rel) throws -> Link {
        guard let link = links.first(where: { $0.rel.contains(rel.rawValue) }) else {
            throw LCPError.linkNotFound(rel: rel.rawValue)
        }
        return link
    }
    
}


extension StatusDocument: CustomStringConvertible {
    
    var description: String {
        return "Status(\(status.rawValue))"
    }
    
}
