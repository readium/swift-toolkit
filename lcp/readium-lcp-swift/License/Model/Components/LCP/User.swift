//
//  User.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/11/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

public struct User {
    /// Unique identifier for the User at a specific Provider.
    public let id: String?
    /// The User’s e-mail address.
    public let email: String?
    /// The User’s name.
    public let name: String?
    /// A list of which user object values are encrypted in this License Document.
    public let encrypted: [String]

    init(json: [String : Any]) throws {
        self.id = json["id"] as? String
        self.email = json["email"] as? String
        self.name = json["name"] as? String
        self.encrypted = (json["encrypted"] as? [String]) ?? []
    }
    
}
