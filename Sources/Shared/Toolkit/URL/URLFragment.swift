//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a fragment identifier in a URL, e.g. `page=2`, without the `#`
/// prefix.
public struct URLFragment: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init?(rawValue: String) {
        guard !rawValue.isEmpty else {
            return nil
        }

        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        precondition(!value.isEmpty, "URLFragment cannot be initialized with an empty string literal")
        rawValue = value
    }
}
