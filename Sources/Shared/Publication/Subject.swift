//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// https://github.com/readium/webpub-manifest/tree/master/contexts/default#subjects
public struct Subject: Hashable, Sendable, JSONValueDecodable, JSONObjectEncodable {
    public var localizedName: LocalizedString
    public var name: String {
        localizedName.string
    }

    public var sortAs: String?
    public var scheme: String? // URI
    public var code: String?
    /// Used to retrieve similar publications for the given subjects.
    public var links: [Link]

    public init(name: LocalizedStringConvertible, sortAs: String? = nil, scheme: String? = nil, code: String? = nil, links: [Link] = []) {
        localizedName = name.localizedString
        self.sortAs = sortAs
        self.scheme = scheme
        self.code = code
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
                warnings?.log("Invalid Subject object", model: Self.self, source: json, severity: .minor)
                throw JSONError.parsing(Self.self)
            }
            self.init(
                name: name,
                sortAs: dict["sortAs"]?.string,
                scheme: dict["scheme"]?.string,
                code: dict["code"]?.string,
                links: dict["links"]?.decode(warnings: warnings) ?? []
            )
        } else {
            warnings?.log("Invalid Subject object", model: Self.self, source: json, severity: .minor)
            throw JSONError.parsing(Self.self)
        }
    }

    public var jsonObject: [String: JSONValue] {
        .init([
            "name": localizedName,
            "sortAs": sortAs,
            "scheme": scheme,
            "code": code,
            "links": links.orNullIfEmpty,
        ])
    }
}
