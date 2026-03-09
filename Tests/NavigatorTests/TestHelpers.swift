//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Allows string literals to be used where ``URLConvertible`` is expected in
/// tests.
extension String: URLConvertible {
    public var anyURL: AnyURL {
        AnyURL(string: self)!
    }
}

/// Allows string literals to be used where ``AnyURL`` is expected in tests.
extension AnyURL: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.init(string: value)!
    }
}
