//
//  StatusDocument.swift
//  r2-lcp-swift
//
//  Created by Alexandre Camilleri on 9/6/17.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Document that contains information about the history of a License Document, along with its current status and available interactions.
public struct StatusDocument {

    public enum Status: String {
        // The License Document is available, but the user hasn't accessed the License and/or Status Document yet.
        case ready
        // The license is active, and a device has been successfully registered for this license. This is the default value if the License Document does not contain a registration link, or a registration mechanism through the license itself.
        case active
        // The license is no longer active, it has been invalidated by the Issuer.
        case revoked
        // The license is no longer active, it has been invalidated by the User.
        case returned
        // The license is no longer active because it was cancelled prior to activation.
        case cancelled
        // The license is no longer active because it has expired.
        case expired
    }

    public enum Rel: String {
        case register
        case license
        case `return`
        case renew
    }
    
    public let id: String
    public let status: Status
    /// A message meant to be displayed to the User regarding the current status of the license.
    public let message: String
    /// Time and Date when the License Document was last updated.
    public let licenseUpdated: Date
    /// Time and Date when the Status Document was last updated.
    public let updated: Date
    public let links: Links
    /// Potential changes allowed for a License Document.
    public let potentialRights: PotentialRights?
    /// Ordered list of events related to the change in status of a License Document.
    public let events: [Event]

    init(data: Data) throws {
        guard let deserializedJSON = try? JSONSerialization.jsonObject(with: data) else {
            throw ParsingError.malformedJSON
        }

        guard let json = deserializedJSON as? [String: Any],
            let id = json["id"] as? String,
            let statusRaw = json["status"] as? String,
            let status = Status(rawValue: statusRaw),
            let message = json["message"] as? String,
            let updated = json["updated"] as? [String: Any],
            let licenseUpdated = (updated["license"] as? String)?.dateFromISO8601,
            let statusUpdated = (updated["status"] as? String)?.dateFromISO8601,
            let links = json["links"] as? [[String: Any]] else
        {
            throw ParsingError.statusDocument
        }
        
        self.id = id
        self.status = status
        self.message = message
        self.licenseUpdated = licenseUpdated
        self.updated = statusUpdated
        self.links = try Links(json: links)
        
        if let potentialRights = json["potential_rights"] as? [String: Any] {
            self.potentialRights = try PotentialRights(json: potentialRights)
        } else {
            self.potentialRights = nil
        }

        if let events = json["events"] as? [[String: Any]] {
            self.events = try events.map(Event.init)
        } else {
            self.events = []
        }
    }

    /// Returns the first link containing the given rel.
    public func link(for rel: Rel) -> Link? {
        return links[rel.rawValue]
    }

    /// Gets and expands the URL for the given rel, if it exits.
    /// - Throws: `LCPError.invalidLink` if the URL can't be built.
    func url(for rel: Rel, with parameters: [String: CustomStringConvertible] = [:]) throws -> URL {
        guard let url = link(for: rel)?.url(with: parameters) else {
            throw LCPError.invalidLink(rel: rel.rawValue)
        }
        
        return url
    }
    
    /// Returns all the events with the given type.
    public func events(for type: Event.EventType) -> [Event] {
        return events(for: type.rawValue)
    }
    
    public func events(for type: String) -> [Event] {
        return events.filter { $0.type == type }
    }
    
}


extension StatusDocument: CustomStringConvertible {
    
    public var description: String {
        return "Status(\(status.rawValue))"
    }
    
}
