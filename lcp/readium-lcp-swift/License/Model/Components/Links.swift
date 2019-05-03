//
//  Links.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 14.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

public struct Links {
    
    private let links: [Link]
    
    init(json: [[String : Any]]) throws {
        links = try json.map(Link.init)
    }

    /// Returns all the links with the given rel.
    public subscript(rel: String) -> [Link] {
        return links.filter { $0.rel.contains(rel) }
    }
    
}
