//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents an HREF, optionally relative to another one.
///
/// This is used to normalize the string representation.
public struct HREF {
    
    private let href: String
    private let baseHREF: String
    
    public init(_ href: String, relativeTo baseHREF: String = "/") {
        let baseHREF = baseHREF.trimmingCharacters(in: .whitespacesAndNewlines)
        self.href = href.trimmingCharacters(in: .whitespacesAndNewlines)
        self.baseHREF = baseHREF.isEmpty ? "/" : baseHREF
    }
    
    /// Returns the normalized string representation for this HREF.
    public var string: String {
        // HREF is just an anchor inside the base.
        if href.isEmpty || href.hasPrefix("#") {
            return baseHREF + href
        }

        // HREF is already absolute.
        if let url = URL(string: href), url.scheme != nil {
            return href
        }

        let baseURL: URL = {
            if let url = URL(string: baseHREF), url.scheme != nil {
                return url
            } else {
                return URL(fileURLWithPath: baseHREF.removingPercentEncoding ?? baseHREF)
            }
        }()

        // Isolates the path from the anchor/query portion, which would be lost otherwise.
        let splitIndex = href.firstIndex(of: "?") ?? href.firstIndex(of: "#") ?? href.endIndex
        let path = String(href[..<splitIndex])
        let suffix = String(href[splitIndex...])

        guard
            let safePath = (path.removingPercentEncoding ?? path)
                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: safePath, relativeTo: baseURL)
        else {
            return baseHREF + "/" + href
        }

        return (url.isHTTP ? url.absoluteString : url.path) + suffix
    }
    
    /// Returns the query parameters present in this HREF, in the order they appear.
    public var queryParameters: [QueryParameter] {
        guard let items = URLComponents(string: href)?.queryItems else {
            return []
        }
        return items.map {
            QueryParameter(name: $0.name, value: $0.value)
        }
    }
    
    static func normalizer(relativeTo baseHREF: String) -> (String) -> String {
        return { href in
            HREF(href, relativeTo: baseHREF).string
        }
    }
    
    public struct QueryParameter: Equatable {
        let name: String
        let value: String?
    }

}

public extension Array where Element == HREF.QueryParameter {
    
    func first(named name: String) -> String? {
        return first { $0.name == name }?.value
    }
    
    func all(named name: String) -> [String] {
        return filter { $0.name == name }.compactMap { $0.value }
    }
    
}
