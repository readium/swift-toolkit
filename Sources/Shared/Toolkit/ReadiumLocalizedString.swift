//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Returns the localized string for `key`.
public func ReadiumLocalizedString(
    _ key: String,
    in bundle: Bundle,
    table: String? = nil,
    _ values: CVarArg...
) -> String {
    ReadiumLocalizedString(key, in: bundle, table: table, values)
}

/// Returns the localized string for `key` with the following lookup order:
///
/// 1. The host app's main bundle (allows the app to override any Readium
///    string).
/// 2. The given module `bundle` in the user's preferred language.
/// 3. The English localization inside the module `bundle` as a last resort.
public func ReadiumLocalizedString(
    _ key: String,
    in bundle: Bundle,
    table: String? = nil,
    _ values: [CVarArg]
) -> String {
    let defaultValue = localizedString(forKey: key, in: bundle, table: table)
    var string = Bundle.main.localizedString(forKey: key, value: defaultValue, table: nil)
    if !values.isEmpty {
        let locale = bundle.preferredLocalizations.first.map(Locale.init(identifier:)) ?? .current
        string = String(format: string, locale: locale, arguments: values)
    }
    return string
}

/// Looks up `key` in `bundle` for the user's preferred language, falling
/// back to the English localization when no translation is found.
private func localizedString(forKey key: String, in bundle: Bundle, table: String?) -> String {
    let value = bundle.localizedString(forKey: key, value: nil, table: table)

    // `localizedString` returns the key itself when no translation exists.
    if value != key {
        return value
    }

    // Fall back to the English localization bundled with the module.
    if
        let enPath = bundle.path(forResource: "en", ofType: "lproj"),
        let enBundle = Bundle(path: enPath)
    {
        let enValue = enBundle.localizedString(forKey: key, value: nil, table: table)
        if enValue != key {
            return enValue
        }
    }

    return key
}
