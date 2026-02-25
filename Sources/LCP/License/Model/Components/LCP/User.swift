//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import ReadiumShared

public struct User: Sendable {
    public typealias ID = String

    /// Unique identifier for the User at a specific Provider.
    public let id: ID?
    /// The User’s e-mail address.
    public let email: String?
    /// The User’s name.
    public let name: String?
    /// Implementor-specific extensions. Each extension is identified by an URI.
    public let extensions: [String: JSONValue]
    /// A list of which user object values are encrypted in this License Document.
    public let encrypted: [String]

    init(json: JSONValue?) throws {
        var json = JSONDictionary(json) ?? JSONDictionary()
        id = json.pop("id")?.string
        email = json.pop("email")?.string
        name = json.pop("name")?.string
        encrypted = parseArray(json.pop("encrypted"))
        extensions = json.json
    }

    init(json: [String: Any]?) throws {
        try self.init(json: JSONValue(json))
    }
}
