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
    public var potentialRights: PotentialRights?
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

    public enum Rel: String {
        case register = "register"
        case license = "license"
        case `return` = "return"
        case renew = "renew"
    }

    public init(data: Data) throws {
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

    /// Returns the date of the latest license update.
    ///
    /// - Returns: The date.
    public func dateOfLatestLicenseDocumentUpdate() -> Date? {
        return updated?.license
    }

    /// Returns the first link containing the given rel.
    ///
    /// - Parameter rel: The rel to look for.
    /// - Returns: The first link containing the rel.
    public func link(withRel rel: Rel) -> Link? {
        return links.first(where: { $0.rel.contains(rel.rawValue) })
    }
    
}


extension StatusDocument: CustomStringConvertible {
    
    public var description: String {
        return "Status(\(status.rawValue))"
    }
    
}
