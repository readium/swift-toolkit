//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Document that contains references to the various keys, links to related external resources, rights and restrictions that are applied to the Protected Publication, and user information.
/// https://github.com/readium/lcp-specs/blob/master/schema/license.schema.json
public struct LicenseDocument: Sendable {
    public typealias ID = String
    public typealias Provider = String

    /// The possible rel of Links.
    public enum Rel: String {
        /// Location where a Reading System can redirect a User looking for additional information about the User Passphrase.
        case hint
        /// Location where the Publication associated with the License Document can be downloaded
        case publication
        /// As defined in the IANA registry of link relations: "Conveys an identifier for the link's context."
        case `self`
        /// Support resources for the user (either a website, an email or a telephone number).
        case support
        /// Location to the Status Document for this license.
        case status
    }

    /// Unique identifier for the Provider (URI).
    public let provider: Provider
    /// Unique identifier for the License.
    public let id: LicenseDocument.ID
    /// Date when the license was first issued.
    public let issued: Date
    /// Date when the license was last updated.
    public let updated: Date
    /// Encryption object.
    public let encryption: Encryption
    /// Used to associate the License Document with resources that are not locally available.
    public let links: Links
    /// The user owning the License.
    public let user: User
    /// Rights informations associated with the License Document
    public let rights: Rights
    /// Used to validate the license integrity.
    public let signature: Signature

    /// JSON representation used to parse the License Document.
    public let jsonData: Data

    /// JSON string representation used to parse the License Document.
    public let jsonString: String

    public init(data: Data) throws {
        guard
            let jsonString = String(data: data, encoding: .utf8),
            let deserializedJSON = try? JSONSerialization.jsonObject(with: data),
            let jsonValue = JSONValue(deserializedJSON)
        else {
            throw ParsingError.malformedJSON
        }

        guard var json = JSONDictionary(jsonValue),
              let provider = json.pop("provider")?.string,
              let id = json.pop("id")?.string,
              let issued = parseDate(json.pop("issued")),
              let encryptionValue = json.pop("encryption"), encryptionValue.object != nil,
              let linksValue = json.pop("links"), linksValue.array != nil,
              let signatureValue = json.pop("signature"), signatureValue.object != nil
        else {
            throw ParsingError.licenseDocument
        }

        self.provider = provider
        self.id = id
        self.issued = issued
        updated = parseDate(json.pop("updated")) ?? issued
        self.encryption = try Encryption(json: encryptionValue)
        self.links = try Links(json: linksValue)
        user = try User(json: json.pop("user"))
        rights = try Rights(json: json.pop("rights"))
        self.signature = try Signature(json: signatureValue)
        jsonData = data
        self.jsonString = jsonString

        // Checks that `links` contains at least one link with `publication` relation.
        guard link(for: .publication) != nil else {
            throw ParsingError.licenseDocument
        }
    }

    /// Link to the protected publication.
    public var publicationLink: Link {
        link(for: .publication)!
    }

    /// Returns the first link containing the given rel.
    public func link(for rel: Rel, type: MediaType? = nil) -> Link? {
        links.firstWithRel(rel.rawValue, type: type)
    }

    /// Returns all the links containing the given rel.
    public func links(for rel: Rel, type: MediaType? = nil) -> [Link] {
        links.filterWithRel(rel.rawValue, type: type)
    }

    /// Gets and expands the URL for the given rel, if it exits.
    ///
    /// If a `preferredType` is given, the first link with both the `rel` and given type will be returned. If none
    /// are found, the first link with the `rel` and an empty `type` will be returned.
    ///
    /// - Throws: `LCPError.invalidLink` if the URL can't be built.
    func url(for rel: Rel, preferredType: MediaType? = nil, parameters: [String: LosslessStringConvertible] = [:]) throws -> HTTPURL {
        let link = link(for: rel, type: preferredType)
            ?? links.firstWithRelAndNoType(rel.rawValue)

        guard let url = link?.url(parameters: parameters) else {
            throw ParsingError.url(rel: rel.rawValue)
        }

        return url
    }
}

extension LicenseDocument: CustomStringConvertible {
    public var description: String {
        "License(\(id))"
    }
}
