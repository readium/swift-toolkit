//
//  HREF.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 15/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Represents an HREF, optionally relative to another one.
///
/// This is used to normalize the string representation.
public struct HREF {
    
    private let href: String
    private let baseHREF: String
    
    public init(_ href: String, relativeTo baseHREF: String) {
        self.href = href
        self.baseHREF = baseHREF.isEmpty ? "/" : baseHREF
    }
    
    /// Returns the normalized string representation for this HREF.
    public var string: String {
        // HREF is just an anchor inside the base.
        if href.hasPrefix("#") {
            return baseHREF + href
        }

        // HREF is already absolute.
        if let url = URL(string: href), url.scheme != nil {
            return href
        }
        
        // Isolates the path from the anchor/query portion, which would be lost otherwise.
        let splitIndex = href.firstIndex(of: "?") ?? href.firstIndex(of: "#") ?? href.endIndex
        let path = String(href[..<splitIndex])
        let suffix = String(href[splitIndex...])

        guard let url = URL(string: path, relativeTo: URL(string: baseHREF)) else {
            return baseHREF
        }
        
        return (url.scheme != nil ? url.absoluteString : url.path) + suffix
    }
    
    static func normalizer(relativeTo baseHREF: String) -> (String) -> String {
        return { href in
            HREF(href, relativeTo: baseHREF).string
        }
    }

}
