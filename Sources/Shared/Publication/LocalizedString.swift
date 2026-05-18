//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Represents a potentially localized string.
/// Can be either:
///   - a single nonlocalized string
///   - a dictionary of localized strings indexed by the BCP 47 language tag
public enum LocalizedString: Hashable, Sendable, JSONValueDecodable, JSONValueEncodable {
    case nonlocalized(String)
    case localized([String: String])

    /// Parses the given JSON representation of the localized string.
    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard let json = json?.jsonValue else {
            return nil
        }

        switch json {
        case let .string(string):
            self = .nonlocalized(string)
        case let .object(dict):
            var strings: [String: String] = [:]
            for (key, value) in dict {
                if let string = value.string {
                    strings[key] = string
                } else {
                    warnings?.log("Invalid value for LocalizedString in dictionary", model: Self.self, source: json, severity: .moderate)
                }
            }
            if strings.isEmpty, !dict.isEmpty {
                throw JSONError.parsing(Self.self)
            }
            self = .localized(strings)
        default:
            warnings?.log("Invalid LocalizedString object", model: Self.self, source: json, severity: .moderate)
            throw JSONError.parsing(Self.self)
        }
    }

    /// Returns the JSON representation for this localized string.
    public var jsonValue: JSONValue {
        switch self {
        case let .nonlocalized(string):
            return .string(string)
        case let .localized(strings):
            return .object(strings.mapValues { .string($0) })
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
    public var description: String {
        string
    }
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
    public var localizedString: LocalizedString {
        .localized(self)
    }
}
