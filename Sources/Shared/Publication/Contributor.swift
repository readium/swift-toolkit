//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// https://readium.org/webpub-manifest/schema/contributor-object.schema.json
public struct Contributor: Hashable, Sendable {
    /// The name of the contributor.
    public var localizedName: LocalizedString
    public var name: String { localizedName.string }

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

    public init(name: LocalizedStringConvertible, identifier: String? = nil, sortAs: String? = nil, roles: [String] = [], role: String? = nil, position: Double? = nil, links: [Link] = []) {
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

    public init?(json: Any, warnings: WarningLogger? = nil) throws {
        if let name = json as? String {
            self.init(name: name)

        } else if let json = json as? [String: Any], let name = try? LocalizedString(json: json["name"], warnings: warnings) {
            self.init(
                name: name,
                identifier: json["identifier"] as? String,
                sortAs: json["sortAs"] as? String,
                roles: parseArray(json["role"], allowingSingle: true),
                position: parseDouble(json["position"]),
                links: .init(json: json["links"], warnings: warnings)
            )

        } else {
            warnings?.log("Invalid Contributor object", model: Self.self, source: json, severity: .moderate)
            throw JSONError.parsing(Self.self)
        }
    }

    public var json: [String: Any] {
        makeJSON([
            "name": localizedName.json,
            "identifier": encodeIfNotNil(identifier),
            "sortAs": encodeIfNotNil(sortAs),
            "role": encodeIfNotEmpty(roles),
            "position": encodeIfNotNil(position),
            "links": encodeIfNotEmpty(links.json),
        ])
    }
}

public extension Array where Element == Contributor {
    /// Parses multiple JSON contributors into an array of Contributors.
    /// eg. let authors = [Contributor](json: ["Apple", "Pear"])
    init(json: Any?, warnings: WarningLogger? = nil) {
        self.init()
        guard let json = json else {
            return
        }

        if let json = json as? [Any] {
            let contributors = json.compactMap { try? Contributor(json: $0, warnings: warnings) }
            append(contentsOf: contributors)
        } else if let contributor = try? Contributor(json: json, warnings: warnings) {
            append(contributor)
        }
    }

    var json: [[String: Any]] {
        map(\.json)
    }
}
