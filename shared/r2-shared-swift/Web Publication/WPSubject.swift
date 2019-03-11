//
//  WPSubject.swift
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
public struct WPSubject: Equatable {
    
    public var name: WPLocalizedString
    public var sortAs: String?
    public var scheme: String?  // URI
    public var code: String?
    
    public init(name: WPLocalizedString, sortAs: String? = nil, scheme: String? = nil, code: String? = nil) {
        self.name = name
        self.sortAs = sortAs
        self.scheme = scheme
        self.code = code
    }
    
    public init(json: Any) throws {
        if let name = json as? String {
            self.name = .nonlocalized(name)
            
        } else if let json = json as? [String: Any] {
            guard let name = try WPLocalizedString(json: json["name"]) else {
                throw WPParsingError.contributor
            }
            self.name = name
            self.sortAs = json["sortAs"] as? String
            self.scheme = json["scheme"] as? String
            self.code = json["code"] as? String

        } else {
            throw WPParsingError.subject
        }
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "name": name.json,
            "sortAs": encodeIfNotNil(sortAs),
            "scheme": encodeIfNotNil(scheme),
            "code": encodeIfNotNil(code)
        ])
    }
    
}

/// Syntactic sugar to parse multiple JSON subjects into an array of WPSubjects.
/// eg. let subjects = [WPSubject](json: ["Apple", "Pear"])
extension Array where Element == WPSubject {
    
    public init(json: Any?) {
        self.init()
        guard let json = json else {
            return
        }
        
        if let json = json as? [Any] {
            let subjects = json.compactMap { try? WPSubject(json: $0) }
            append(contentsOf: subjects)
        } else if let subject = try? WPSubject(json: json) {
            append(subject)
        }
    }
    
    public var json: [[String: Any]] {
        return map { $0.json }
    }
    
}
