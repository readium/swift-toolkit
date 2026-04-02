//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// https://readium.org/webpub-manifest/schema/contributor.schema.json
public struct Contributor: Hashable, Sendable, JSONValueDecodable, JSONObjectEncodable {
    /// The name of the contributor.
    public var localizedName: LocalizedString
    public var name: String {
        localizedName.string
    }

    /// An unambiguous reference to this contributor.
    public var identifier: String?

    /// The string used to sort the name of the contributor.
    public var sortAs: String?

    /// The role of the contributor in the publication making.
    public var roles: [String]

    /// The position of the publication in this collection/series, when the contributor represents a collection.
    public var position: Double?

    /// Used to retrieve similar publications for the given contributor.
    public var links: [Link]

    public init(
        name: LocalizedStringConvertible,
        identifier: String? = nil,
        sortAs: String? = nil,
        roles: [String] = [],
        role: String? = nil,
        position: Double? = nil,
        links: [Link] = []
    ) {
        // convenience to set a single role during construction
        var roles = roles
        if let role = role {
            roles.append(role)
        }

        localizedName = name.localizedString
        self.identifier = identifier
        self.sortAs = sortAs
        self.roles = roles
        self.position = position
        self.links = links
    }

    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard let json = json?.jsonValue else {
            return nil
        }

        if let name = json.string {
            self.init(name: name)
        } else if let dict = json.object {
            guard let name: LocalizedString = try? dict["name"]?.decode(warnings: warnings) else {
                warnings?.log("Invalid Contributor object", model: Self.self, source: json, severity: .moderate)
                throw JSONError.parsing(Self.self)
            }
            self.init(
                name: name,
                identifier: dict["identifier"]?.string,
                sortAs: dict["sortAs"]?.string,
                roles: dict["role"]?.decode(allowingSingle: true) ?? [],
                position: dict["position"]?.double,
                links: dict["links"]?.decode(warnings: warnings) ?? []
            )
        } else {
            warnings?.log("Invalid Contributor object", model: Self.self, source: json, severity: .moderate)
            throw JSONError.parsing(Self.self)
        }
    }

    public var jsonObject: [String: JSONValue] {
        .init([
            "name": localizedName,
            "identifier": identifier,
            "sortAs": sortAs,
            "role": roles.orNullIfEmpty,
            "position": position,
            "links": links.orNullIfEmpty,
        ])
    }
}
