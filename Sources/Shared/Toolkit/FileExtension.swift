//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a file extension.
public struct FileExtension: Hashable, RawRepresentable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        precondition(!rawValue.isEmpty && !rawValue.hasPrefix("."))
        self.rawValue = rawValue.lowercased()
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }

    /// Appends this file extension to `filename`.
    public func appendedToFilename(_ filename: String) -> String {
        "\(filename).\(rawValue)"
    }

    public static let audiobook = FileExtension(rawValue: "audiobook")
    public static let cbz = FileExtension(rawValue: "cbz")
    public static let divina = FileExtension(rawValue: "divina")
    public static let epub = FileExtension(rawValue: "epub")
    public static let json = FileExtension(rawValue: "json")
    public static let lcpa = FileExtension(rawValue: "lcpa")
    public static let lcpdf = FileExtension(rawValue: "lcpdf")
    public static let lcpl = FileExtension(rawValue: "lcpl")
    public static let pdf = FileExtension(rawValue: "pdf")
    public static let webpub = FileExtension(rawValue: "webpub")
}

public extension Optional where Wrapped == FileExtension {
    /// Appends this file extension to `filename`.
    func appendedToFilename(_ filename: String) -> String {
        switch self {
        case let .some(ext):
            return ext.appendedToFilename(filename)
        case .none:
            return filename
        }
    }
}
