//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a file extension.
public struct FileExtension: Hashable, RawRepresentable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        precondition(!rawValue.isEmpty && rawValue.hasPrefix("."))
        self.rawValue = rawValue.lowercased()
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }

    /// Appends this file extension to `filename`.
    public func appendToFilename(_ filename: String) -> String {
        "\(filename).\(rawValue)"
    }
}
