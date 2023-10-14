//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a list of query parameters in a URL.
public struct URLQuery {

    /// Represents a single query parameter and its value in a URL.
    public struct Parameter {
        public let name: String
        public let value: String?
    }

    public let parameters: [Parameter]

    public init(parameters: [Parameter] = []) {
        self.parameters = parameters
    }
    
    public init(url: URL) {
        let parameters = URLComponents(url: url, resolvingAgainstBaseURL: true)?
            .queryItems?
            .map { Parameter(name: $0.name, value: $0.value) }
        
        self.init(parameters: parameters ?? [])
    }

    /// Returns the first value for the parameter with the given `name`.
    public func first(named name: String) -> String? {
        parameters.first(where: { $0.name == name })?.value
    }

    /// Returns all the values for the parameter with the given `name`.
    public func all(named name: String) -> [String] {
        parameters.filter { $0.name == name }.compactMap(\.value)
    }
}
