//
//  Subject.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 11.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


// https://github.com/readium/webpub-manifest/tree/master/contexts/default#subjects
public struct Subject: Equatable {
    
    public var localizedName: LocalizedString
    public var name: String { return localizedName.string }
    public var sortAs: String?
    public var scheme: String?  // URI
    public var code: String?
    /// Used to retrieve similar publications for the given subjects.
    public var links: [Link] = []
    
    public init(name: LocalizedStringConvertible, sortAs: String? = nil, scheme: String? = nil, code: String? = nil, links: [Link] = []) {
        self.localizedName = name.localizedString
        self.sortAs = sortAs
        self.scheme = scheme
        self.code = code
        self.links = links
    }
    
    public init(json: Any) throws {
        if let name = json as? String {
            self.localizedName = name.localizedString

        } else if let json = json as? [String: Any] {
            guard let name = try LocalizedString(json: json["name"]) else {
                throw JSONError.parsing(Subject.self)
            }
            self.localizedName = name
            self.sortAs = json["sortAs"] as? String
            self.scheme = json["scheme"] as? String
            self.code = json["code"] as? String
            self.links = [Link](json: json["links"])

        } else {
            throw JSONError.parsing(Subject.self)
        }
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "name": localizedName.json,
            "sortAs": encodeIfNotNil(sortAs),
            "scheme": encodeIfNotNil(scheme),
            "code": encodeIfNotNil(code),
            "links": encodeIfNotEmpty(links.json)
        ])
    }

}

extension Array where Element == Subject {
    
    /// Parses multiple JSON subjects into an array of Subjects.
    /// eg. let subjects = [Subject](json: ["Apple", "Pear"])
    public init(json: Any?) {
        self.init()
        guard let json = json else {
            return
        }
        
        if let json = json as? [Any] {
            let subjects = json.compactMap { try? Subject(json: $0) }
            append(contentsOf: subjects)
        } else if let subject = try? Subject(json: json) {
            append(subject)
        }
    }
    
    public var json: [[String: Any]] {
        return map { $0.json }
    }
    
}
