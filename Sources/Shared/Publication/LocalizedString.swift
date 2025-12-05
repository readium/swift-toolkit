//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a potentially localized string.
/// Can be either:
///   - a single nonlocalized string
///   - a dictionary of localized strings indexed by the BCP 47 language tag
public enum LocalizedString: Hashable, Sendable {
    case nonlocalized(String)
    case localized([String: String])

    /// Parses the given JSON representation of the localized string.
    ///   "anyOf": [
    ///     {
    ///       "type": "string"
    ///     },
    ///     {
    ///       "description": "The language in a language map must be a valid BCP 47 tag.",
    ///       "type": "object",
    ///       "patternProperties": {
    ///         "^((?<grandfathered>(en-GB-oed|i-ami|i-bnn|i-default|i-enochian|i-hak|i-klingon|i-lux|i-mingo|i-navajo|i-pwn|i-tao|i-tay|i-tsu|sgn-BE-FR|sgn-BE-NL|sgn-CH-DE)|(art-lojban|cel-gaulish|no-bok|no-nyn|zh-guoyu|zh-hakka|zh-min|zh-min-nan|zh-xiang))|((?<language>([A-Za-z]{2,3}(-(?<extlang>[A-Za-z]{3}(-[A-Za-z]{3}){0,2}))?)|[A-Za-z]{4}|[A-Za-z]{5,8})(-(?<script>[A-Za-z]{4}))?(-(?<region>[A-Za-z]{2}|[0-9]{3}))?(-(?<variant>[A-Za-z0-9]{5,8}|[0-9][A-Za-z0-9]{3}))*(-(?<extension>[0-9A-WY-Za-wy-z](-[A-Za-z0-9]{2,8})+))*(-(?<privateUse>x(-[A-Za-z0-9]{1,8})+))?)|(?<privateUse2>x(-[A-Za-z0-9]{1,8})+))$": {
    ///           "type": "string"
    ///         }
    ///       },
    ///       "additionalProperties": false,
    ///       "minProperties": 1
    ///     }
    ///   ]
    public init?(json: Any?, warnings: WarningLogger? = nil) throws {
        if json == nil {
            return nil
        } else if let string = json as? String {
            self = .nonlocalized(string)
        } else if let strings = json as? [String: String] {
            self = .localized(strings)
        } else {
            warnings?.log("Invalid LocalizedString object", model: Self.self, source: json, severity: .moderate)
            throw JSONError.parsing(Self.self)
        }
    }

    /// Returns the JSON representation for this localized string.
    public var json: Any {
        switch self {
        case let .nonlocalized(string):
            return string
        case let .localized(strings):
            return strings
        }
    }

    /// Returns the localized string matching the most the user's locale.
    public var string: String {
        string(forLanguageCode: nil)
    }

    /// Returns the localized string matching the given locale, or fallback on the user's locale.
    public func string(forLocale locale: Locale) -> String {
        string(forLanguageCode: locale.languageCode)
    }

    /// Returns the localized string matching the given language code, or fallback on the user's locale.
    public func string(forLanguageCode languageCode: String?) -> String {
        switch self {
        case let .nonlocalized(string):
            return string
        case let .localized(strings):
            guard let languageCode = languageCode, let string = strings[languageCode] else {
                // Recovers using the user's preferred language in the available ones
                // See. https://developer.apple.com/library/archive/technotes/tn2418/_index.html
                let availableLanguages = Array(strings.keys)
                if let code = Bundle.preferredLocalizations(from: availableLanguages).first, let string = strings[code] {
                    return string
                }
                // According to the JSON schema, there's always at least one value. We fallback on an empty string just in case.
                return strings["en"] ?? strings.first?.value ?? ""
            }
            return string
        }
    }
}

extension LocalizedString: CustomStringConvertible {
    public var description: String { string }
}

/// Provides syntactic sugar when initializing a LocalizedString from a regular String (nonlocalized) or a [String: String] (localized).
public protocol LocalizedStringConvertible {
    var localizedString: LocalizedString { get }
}

extension String: LocalizedStringConvertible {
    public var localizedString: LocalizedString {
        .nonlocalized(self)
    }
}

extension LocalizedString: LocalizedStringConvertible {
    public var localizedString: LocalizedString {
        self
    }
}

extension Dictionary: LocalizedStringConvertible where Key == String, Value == String {
    public var localizedString: LocalizedString { .localized(self) }
}
