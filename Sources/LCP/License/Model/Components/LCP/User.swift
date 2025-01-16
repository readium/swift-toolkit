//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public struct User {
    public typealias ID = String

    /// Unique identifier for the User at a specific Provider.
    public let id: ID?
    /// The User’s e-mail address.
    public let email: String?
    /// The User’s name.
    public let name: String?
    /// Implementor-specific extensions. Each extension is identified by an URI.
    public let extensions: [String: Any]
    /// A list of which user object values are encrypted in this License Document.
    public let encrypted: [String]

    init(json: [String: Any]?) throws {
        var json = json ?? [:]
        id = json.removeValue(forKey: "id") as? String
        email = json.removeValue(forKey: "email") as? String
        name = json.removeValue(forKey: "name") as? String
        encrypted = (json.removeValue(forKey: "encrypted") as? [String]) ?? []
        extensions = json
    }
}
