//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public struct User: JSONValueDecodable {
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

    public init(
        id: ID? = nil,
        email: String? = nil,
        name: String? = nil,
        extensions: [String: JSONValue] = [:],
        encrypted: [String] = []
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.extensions = extensions
        self.encrypted = encrypted
    }

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard let json = json?.jsonValue else {
            return nil
        }

        var dict = json.object ?? [:]

        id = dict.pop("id")?.string
        email = dict.pop("email")?.string
        name = dict.pop("name")?.string
        encrypted = dict.pop("encrypted")?.decode() ?? []
        extensions = dict
    }
}
