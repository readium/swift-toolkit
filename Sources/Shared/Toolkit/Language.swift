//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A language identified by a BCP 47 tag, e.g. `en`, `en-US` or `zh-Hant-TW`.
///
/// The tag is parsed leniently into its language, script and region subtags,
/// and rebuilt with their canonical casing. Two languages are equal when their
/// canonical tags are equal, so `en-US`, `en-us` and `en_US` are the same
/// language.
public struct Language: Hashable, Sendable, JSONValueDecodable, JSONValueEncodable {
    public static var current: Language {
        Language(locale: Locale.current)
    }

    /// List of all available languages on the device.
    public static let all: [Language] =
        Locale.availableIdentifiers
            .map { Language($0) }

    /// Canonical BCP 47 tag, e.g. `zh-Hant-TW`.
    public let tag: String

    /// Primary language subtag, e.g. `zh`.
    public let code: Code

    /// Script subtag, e.g. `Hant`.
    public let script: Script?

    /// Region subtag, e.g. `TW`.
    public let region: Region?

    /// Primary language subtag, lowercased, e.g. `zh`.
    ///
    /// Only the case is normalized, the value is not validated.
    public struct Code: Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
        public let rawValue: String

        public init(_ value: String) {
            rawValue = value.lowercased()
        }

        public init(stringLiteral value: String) {
            self.init(value)
        }

        public var description: String { rawValue }

        /// Localized name of the subtag, or `nil` if it is empty or unknown.
        public func localizedName(in targetLocale: Locale = Locale.current) -> String? {
            guard !rawValue.isEmpty else {
                return nil
            }
            return targetLocale.localizedString(forLanguageCode: rawValue)
        }
    }

    /// Script subtag, title-cased, e.g. `Hant`.
    ///
    /// Only the case is normalized, the value is not validated.
    public struct Script: Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
        public let rawValue: String

        public init(_ value: String) {
            rawValue = value.prefix(1).uppercased() + value.dropFirst().lowercased()
        }

        public init(stringLiteral value: String) {
            self.init(value)
        }

        public var description: String { rawValue }

        /// Localized name of the subtag, or `nil` if it is empty or unknown.
        public func localizedName(in targetLocale: Locale = Locale.current) -> String? {
            guard !rawValue.isEmpty else {
                return nil
            }
            return targetLocale.localizedString(forScriptCode: rawValue)
        }
    }

    /// Region subtag, upper-cased, e.g. `TW` or `419`.
    ///
    /// Only the case is normalized, the value is not validated.
    public struct Region: Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
        public let rawValue: String

        public init(_ value: String) {
            rawValue = value.uppercased()
        }

        public init(stringLiteral value: String) {
            self.init(value)
        }

        public var description: String { rawValue }

        /// Localized name of the subtag, or `nil` if it is empty or unknown.
        public func localizedName(in targetLocale: Locale = Locale.current) -> String? {
            guard !rawValue.isEmpty else {
                return nil
            }
            return targetLocale.localizedString(forRegionCode: rawValue)
        }
    }

    /// Creates a language from a BCP 47 tag or a `Locale` identifier.
    ///
    /// The parsing is lenient and does not validate the tag:
    /// - The surrounding whitespaces and the `Locale` keywords starting with
    ///   `@` are ignored, e.g. `zh_TW@calendar=roc` gives `zh-TW`.
    /// - `_` is read as `-`, and empty subtags are ignored.
    /// - The first subtag is the language, lowercased.
    /// - Up to three 3-letter extended language subtags (e.g. `yue` in
    ///   `zh-yue-HK`) are kept in the tag, lowercased.
    /// - An optional 4-letter subtag is the script, title-cased.
    /// - An optional 2-letter or 3-digit subtag is the region, upper-cased.
    /// - The other subtags (variants, extensions and private use) are kept
    ///   in the tag, lowercased. Any subtag which is not of the expected kind,
    ///   such as a singleton (e.g. `x`), ends the parsing of the script and
    ///   region.
    public init(_ tag: String) {
        var subtags = tag
            .prefix { $0 != "@" }
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .map { $0.lowercased() }[...]

        func popFirst(where predicate: (String) -> Bool) -> String? {
            guard let subtag = subtags.first, predicate(subtag) else {
                return nil
            }
            return subtags.removeFirst()
        }

        let code = Code(subtags.popFirst() ?? "")

        var extlangs: [String] = []
        while extlangs.count < 3, let extlang = popFirst(where: { $0.count == 3 && $0.isASCIILetters }) {
            extlangs.append(extlang)
        }

        let script = popFirst(where: { $0.count == 4 && $0.isASCIILetters })
            .map { Script($0) }

        let region = popFirst(where: { ($0.count == 2 && $0.isASCIILetters) || ($0.count == 3 && $0.isASCIIDigits) })
            .map { Region($0) }

        self.code = code
        self.script = script
        self.region = region
        self.tag = ([code.rawValue] + extlangs + [script?.rawValue, region?.rawValue].compactMap { $0 } + subtags)
            .joined(separator: "-")
    }

    /// Creates a language from the identifier of a `Locale`, ignoring its
    /// keywords, e.g. `zh_TW@calendar=roc` gives `zh-TW`.
    public init(locale: Locale) {
        self.init(locale.identifier)
    }

    public init?<T: JSONValueEncodable>(json: T?, warnings: (any WarningLogger)?) throws {
        guard let tag = json?.jsonValue.string else {
            return nil
        }
        self.init(tag)
    }

    public var locale: Locale {
        Locale(identifier: tag)
    }

    public func localizedDescription(in locale: Locale = Locale.current) -> String {
        locale.localizedString(forIdentifier: tag)
            ?? tag
    }

    public func localizedLanguage(in targetLocale: Locale = Locale.current) -> String? {
        code.localizedName(in: targetLocale)
    }

    public func localizedRegion(in targetLocale: Locale = Locale.current) -> String? {
        region?.localizedName(in: targetLocale)
    }

    /// The language with only its primary language subtag, e.g. `zh-Hant-TW`
    /// gives `zh`.
    public var primaryLanguage: Language {
        Language(code.rawValue)
    }

    @available(*, unavailable, message: "Use the `primaryLanguage` property instead")
    public func removingRegion() -> Language {
        fatalError()
    }

    public var jsonValue: JSONValue {
        .string(tag)
    }

    public static func == (lhs: Language, rhs: Language) -> Bool {
        lhs.tag == rhs.tag
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(tag)
    }
}

extension Language: CustomStringConvertible {
    public var description: String {
        tag
    }
}

extension Language: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
}

extension Language: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let tag = try container.decode(String.self)
        self.init(tag)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(tag)
    }
}

private extension String {
    var isASCIILetters: Bool {
        allSatisfy { $0.isASCII && $0.isLetter }
    }

    var isASCIIDigits: Bool {
        allSatisfy { $0.isASCII && $0.isNumber }
    }
}
