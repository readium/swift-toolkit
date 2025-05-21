//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Document that contains information about the history of a License Document, along with its current status and available interactions.
/// https://github.com/readium/lcp-specs/blob/master/schema/status.schema.json
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
              let links = json["links"] as? [[String: Any]]
        else {
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
            potentialRights = nil
        }

        if let events = json["events"] as? [[String: Any]] {
            self.events = events.compactMap(Event.init)
        } else {
            events = []
        }
    }

    /// Returns the first link containing the given rel.
    public func link(for rel: Rel, type: MediaType? = nil) -> Link? {
        links.firstWithRel(rel.rawValue, type: type)
    }

    /// Returns all the links containing the given rel.
    public func links(for rel: Rel, type: MediaType? = nil) -> [Link] {
        links.filterWithRel(rel.rawValue, type: type)
    }

    func linkWithNoType(for rel: Rel) -> Link? {
        links.firstWithRelAndNoType(rel.rawValue)
    }

    /// Gets and expands the URL for the given rel, if it exits.
    ///
    /// If a `preferredType` is given, the first link with both the `rel` and given type will be returned. If none
    /// are found, the first link with the `rel` and an empty `type` will be returned.
    ///
    /// - Throws: `LCPError.invalidLink` if the URL can't be built.
    func url(for rel: Rel, preferredType: MediaType? = nil, parameters: [String: LosslessStringConvertible] = [:]) throws -> HTTPURL {
        let link = link(for: rel, type: preferredType)
            ?? linkWithNoType(for: rel)

        guard let url = link?.url(parameters: parameters) else {
            throw ParsingError.url(rel: rel.rawValue)
        }

        return url
    }

    /// Returns all the events with the given type.
    public func events(for type: Event.EventType) -> [Event] {
        events(for: type.rawValue)
    }

    public func events(for type: String) -> [Event] {
        events.filter { $0.type == type }
    }
}

extension StatusDocument: CustomStringConvertible {
    public var description: String {
        "Status(\(status.rawValue))"
    }
}
