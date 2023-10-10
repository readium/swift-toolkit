//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension URL {
    /// Creates a `URL` from a percent-decoded relative path.
    public init?(decodedPath: String) {
        guard let path = decodedPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        self.init(string: path)
    }

    /// Removes the fragment portion of the receiver and returns it.
    public mutating func removeFragment() -> String? {
        var fragment: String?
        guard let result = copy({
            fragment = $0.fragment
            $0.fragment = nil
        }) else {
            return nil
        }
        self = result
        return fragment
    }

    /// Creates a copy of the receiver after removing its fragment portion.
    public func removingFragment() -> URL? {
        copy { $0.fragment = nil }
    }

    /// Creates a copy of the receiver after modifying its components.
    public func copy(_ changes: (inout URLComponents) -> Void) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return nil
        }
        changes(&components)
        return components.url
    }
}

public extension URL {
    /// Returns the query parameters present in this HREF, in the order they
    /// appear.
    var queryParameters: [QueryParameter] {
        guard let items = URLComponents(url: self, resolvingAgainstBaseURL: true)?.queryItems else {
            return []
        }
        return items.map {
            QueryParameter(name: $0.name, value: $0.value)
        }
    }

    struct QueryParameter: Equatable {
        let name: String
        let value: String?
    }
}

public extension Array where Element == URL.QueryParameter {
    func first(named name: String) -> String? {
        first { $0.name == name }?.value
    }

    func all(named name: String) -> [String] {
        filter { $0.name == name }.compactMap(\.value)
    }
}
