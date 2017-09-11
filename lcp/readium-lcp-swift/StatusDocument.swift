//
//  StatusDocument.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 9/6/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import SwiftyJSON

/// Document that contains information about the history of a License Document,
/// along with its current status and available interactions.
public class StatusDocument {
    public var id: String
    public var status: Status
    /// A message meant to be displayed to the User regarding the current status
    /// of the license.
    public var message: String
    /// Must contain at least a link to the LicenseDocument associated to this.
    /// Status Document.
    public var links = [Link]()

    public var updated: Updated?
    /// Dictionnary of potential rights associated with Dates.
    public var potentialRights = [Right: Date]()
    /// Ordered list of events related to the change in status of a License
    /// Document.
    public var events: [Event]!

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
    public enum Status: String {
        case ready
        case active
        case revoked
        case returned
        case cancelled
        case expired
    }

    /// List of potential changes allowed for a License Document.
    ///
    /// - end: Time and Date when the license ends.
    public enum Right: String {
        case end
    }
    
    public init(with data: Data) throws {
        let json = JSON(data: data)

        // Retrieves the non optional fields.
        guard let id = json["id"].string,
            let statusData = json["status"].string,
            let status = Status(rawValue: statusData),
            let message = json["message"].string else
        {
            throw LcpError.json
        }
        self.id = id
        self.status = status
        self.message = message
        self.updated = try Updated.init(with: json["updated"])
        links = try parseLinks(json)
        events = try parseEvents(json)
        parsePotentialRights(json)
    }

    /// Parses the Potential Rights, if any.
    ///
    /// - Parameter json: The JSON representing the Potential Rights
    internal func parsePotentialRights(_ json: JSON) {
        guard let potentialRights = json["potential_rights"].dictionary else {
            return
        }
        for potentialRight in potentialRights {
            if let right = Right.init(rawValue: potentialRight.key),
                let date = potentialRight.value.string?.dateFromISO8601 {

                self.potentialRights[right] = date
            }
        }
    }
}
