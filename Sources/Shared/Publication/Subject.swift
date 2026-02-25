//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// https://github.com/readium/webpub-manifest/tree/master/contexts/default#subjects
public struct Subject: Hashable, Sendable {
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

    public init?(json: JSONValue?, warnings: WarningLogger? = nil) throws {
        guard let json = json else {
            return nil
        }

        switch json {
        case let .string(name):
            self.init(name: name)
        case let .object(dict):
            guard let name = try? LocalizedString(json: dict["name"], warnings: warnings) else {
                warnings?.log("Invalid Subject object", model: Self.self, source: json, severity: .minor)
                throw JSONError.parsing(Self.self)
            }
            self.init(
                name: name,
                sortAs: dict["sortAs"]?.string,
                scheme: dict["scheme"]?.string,
                code: dict["code"]?.string,
                links: .init(json: dict["links"])
            )
        default:
            warnings?.log("Invalid Subject object", model: Self.self, source: json, severity: .minor)
            throw JSONError.parsing(Self.self)
        }
    }

    public init?(json: Any, warnings: WarningLogger? = nil) throws {
        try self.init(json: JSONValue(json), warnings: warnings)
    }

    public var json: [String: JSONValue] {
        makeJSON([
            "name": localizedName.json,
            "sortAs": encodeIfNotNil(sortAs),
            "scheme": encodeIfNotNil(scheme),
            "code": encodeIfNotNil(code),
            "links": encodeIfNotEmpty(links.json),
        ] as [String: JSONValue])
    }
}

public extension Array where Element == Subject {
    /// Parses multiple JSON subjects into an array of Subjects.
    /// eg. let subjects = [Subject](json: ["Apple", "Pear"])
    init(json: JSONValue?, warnings: WarningLogger? = nil) {
        self.init()
        guard let json = json else {
            return
        }

        switch json {
        case let .array(array):
            let subjects = array.compactMap { try? Subject(json: $0, warnings: warnings) }
            append(contentsOf: subjects)
        default:
            if let subject = try? Subject(json: json, warnings: warnings) {
                append(subject)
            }
        }
    }

    init(json: Any?, warnings: WarningLogger? = nil) {
        self.init(json: JSONValue(json), warnings: warnings)
    }

    var json: [[String: JSONValue]] {
        map(\.json)
    }
}
