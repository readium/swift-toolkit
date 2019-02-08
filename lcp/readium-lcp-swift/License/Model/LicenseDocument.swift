//
//  LicenseDocument.swift
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
import R2Shared

/// Document that contains references to the various keys, links to related
/// external resources, rights and restrictions that are applied to the
/// Protected Publication, and user information.
class LicenseDocument {
    var id: String
    /// Date when the license was first issued.
    var issued: Date
    /// Date when the license was last updated.
    var updated: Date?
    /// Unique identifier for the Provider (URI).
    var provider: URL
    // Encryption object.
    var encryption: Encryption
    /// Used to associate the License Document with resources that are not 
    /// locally available.
    var links = [Link]()
    /// Rights informations associated with the License Document
    var rights: Rights
    /// The user owning the License.
    var user: User
    /// Used to validate the license integrity.
    var signature: Signature

    var json: String
    
    var data: Data {
        return json.data(using: .utf8) ?? Data()
    }

    // The possible rel of Links.
    enum Rel: String {
        case hint = "hint"
        case publication = "publication"
        case status = "status"
    }

    init(with data: Data) throws {
        let json = JSON(data: data)

        guard let id = json["id"].string,
            let issued = json["issued"].string,
            let issuedDate = issued.dateFromISO8601,
            let provider = json["provider"].url else
        {
            throw ParsingError.json
        }
        guard let jsonString = String.init(data: data, encoding: String.Encoding.utf8) else {
            throw ParsingError.json
        }
        self.json = jsonString
        self.id = id
        self.issued = issuedDate
        self.provider = provider
        //
        encryption = try Encryption.init(with: json["encryption"])
        links = try parseLinks(json["links"])
        rights = Rights.init(with: json["rights"])
        if let potentialEnd = json["potential_rights"]["end"].string?.dateFromISO8601 {
            rights.potentialEnd = potentialEnd
        }
        user = User.init(with: json["user"])
        signature = try Signature.init(with: json["signature"])
        if let updated = json["updated"].string,
            let updatedDate = updated.dateFromISO8601 {
            self.updated = updatedDate
        }
        /// Check that links contains rel for Hint and Publication.
        guard (link(withRel: Rel.hint) != nil) else {
            throw LCPError.hintLinkNotFound
        }
        guard (link(withRel: Rel.publication) != nil) else {
            throw LCPError.publicationLinkNotFound
        }
    }

    /// Returns the date of last update if any, or issued date.
    func dateOfLastUpdate() -> Date {
        return ((updated != nil) ? updated! : issued)
    }

    /// Returns the first link containing the given rel.
    ///
    /// - Parameter rel: The rel to look for.
    /// - Returns: The first link containing the rel.
    func link(withRel rel: Rel) -> Link? {
        return links.first(where: { $0.rel.contains(rel.rawValue) })
    }

    func getHint() -> String {
        return encryption.userKey.hint
    }

}

extension LicenseDocument: CustomStringConvertible {
    
    var description: String {
        return "License(\(id))"
    }
    
}
