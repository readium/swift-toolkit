//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

// https://github.com/readium/webpub-manifest/tree/master/contexts/default#subjects
public struct Subject: Hashable, Sendable {
    public var localizedName: LocalizedString
    public var name: String { localizedName.string }
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

    public init?(json: Any, warnings: WarningLogger? = nil) throws {
        if let name = json as? String {
            self.init(name: name)

        } else if let json = json as? [String: Any], let name = try? LocalizedString(json: json["name"], warnings: warnings) {
            self.init(
                name: name,
                sortAs: json["sortAs"] as? String,
                scheme: json["scheme"] as? String,
                code: json["code"] as? String,
                links: .init(json: json["links"])
            )

        } else {
            warnings?.log("Invalid Subject object", model: Self.self, source: json, severity: .minor)
            throw JSONError.parsing(Self.self)
        }
    }

    public var json: [String: Any] {
        makeJSON([
            "name": localizedName.json,
            "sortAs": encodeIfNotNil(sortAs),
            "scheme": encodeIfNotNil(scheme),
            "code": encodeIfNotNil(code),
            "links": encodeIfNotEmpty(links.json),
        ])
    }
}

public extension Array where Element == Subject {
    /// Parses multiple JSON subjects into an array of Subjects.
    /// eg. let subjects = [Subject](json: ["Apple", "Pear"])
    init(json: Any?, warnings: WarningLogger? = nil) {
        self.init()
        guard let json = json else {
            return
        }

        if let json = json as? [Any] {
            let subjects = json.compactMap { try? Subject(json: $0, warnings: warnings) }
            append(contentsOf: subjects)
        } else if let subject = try? Subject(json: json, warnings: warnings) {
            append(subject)
        }
    }

    var json: [[String: Any]] {
        map(\.json)
    }
}
