//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public struct Language: Hashable, Sendable {
    public static var current: Language {
        Language(locale: Locale.current)
    }

    /// List of all available languages on the device.
    public static let all: [Language] =
        Locale.availableIdentifiers
            .map { Language(code: .bcp47($0)) }

    public enum Code: Hashable, Sendable {
        case bcp47(String)

        public var bcp47: String {
            switch self {
            case let .bcp47(code):
                return code
            }
        }

        public func removingRegion() -> Code {
            .bcp47(String(bcp47.prefix { $0 != "-" && $0 != "_" }))
        }
    }

    public let code: Code

    public var locale: Locale { Locale(identifier: code.bcp47) }

    public func localizedDescription(in locale: Locale = Locale.current) -> String {
        locale.localizedString(forIdentifier: code.bcp47)
            ?? code.bcp47
    }

    public func localizedLanguage(in targetLocale: Locale = Locale.current) -> String? {
        locale.languageCode.flatMap { targetLocale.localizedString(forLanguageCode: $0) }
    }

    public func localizedRegion(in targetLocale: Locale = Locale.current) -> String? {
        locale.regionCode.flatMap { targetLocale.localizedString(forRegionCode: $0) }
    }

    public init(code: Code) {
        self.code = code
    }

    public init(locale: Locale) {
        self.init(code: .bcp47(locale.identifier))
    }

    public func removingRegion() -> Language {
        Language(code: code.removingRegion())
    }
}

extension Language: CustomStringConvertible {
    public var description: String {
        code.bcp47
    }
}

extension Language: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.init(code: .bcp47(value))
    }
}

extension Language: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let code = try container.decode(String.self)
        self.init(code: .bcp47(code))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(code.bcp47)
    }
}
