//
//  User.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/11/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import SwiftyJSON

public struct User {
    /// Unique identifier for the User at a specific Provider.
    var id: String?
    /// The User’s e-mail address.
    var email: String?
    /// The User’s name.
    var name: String?
    /// A list of which user object values are encrypted in this License
    /// Document.
    var encrypted = [String]()

    init(with json: JSON) {
        id = json["id"].string
        email = json["email"].string
        name = json["name"].string
        if let encrypted = json["encrypted"].arrayObject {
            self.encrypted = encrypted as! [String]
        }
    }
}
