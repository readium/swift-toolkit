//
//  LicenseDocument.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 9/6/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import SwiftyJSON

/// Document that contains references to the various keys, links to related
/// external resources, rights and restrictions that are applied to the
/// Protected Publication, and user information.
public class LicenseDocument {
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
    ///
    var rights: Rights
    /// The user owning the License.
    var user: User
    /// Used to validate the license integrity.
    var signature: Signature

    init(with data: Data) throws {
        let json = JSON.init(data: data)

        guard let id = json["id"].string,
            let issued = json["issued"].string,
            let issuedDate = issued.dateFromISO8601,
            let provider = json["provider"].url else
        {
            throw LcpError.json
        }
        self.id = id
        self.issued = issuedDate
        self.provider = provider
        encryption = try Encryption.init(with: json["enryption"])
        links = try parseLinks(json["links"])
        rights = Rights.init(with: json["rights"])
        user = User.init(with: json["user"])
        signature = try Signature.init(with: json["signature"])
        if let updated = json["updated"].string,
            let updatedDate = updated.dateFromISO8601 {
            self.updated = updatedDate
        }
        /// Check that links contains rel for Hint and Publication.
        guard links.contains(where: { $0.rel.contains("hint") }),
            links.contains(where: { $0.rel.contains("publication") }) else {
            throw LcpError.link
        }
    }
}

