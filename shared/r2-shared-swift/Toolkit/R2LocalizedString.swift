//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Returns the localized string in the main bundle, or fallback on the given bundle if not found.
/// Can be used to override framework localized strings in the host app.
public func R2LocalizedString(_ key: String, in bundle: Bundle, _ values: [CVarArg]) -> String {
    let defaultValue = bundle.localizedString(forKey: key, value: nil, table: nil)
    var string = Bundle.main.localizedString(forKey: key, value: defaultValue, table: nil)
    if !values.isEmpty {
        string = String(format: string, locale: Locale.current, arguments: values)
    }
    return string
}

public func R2LocalizedString(_ key: String, in bundleID: String, _ values: [CVarArg]) -> String {
    let defaultValue = Bundle(identifier: bundleID)?.localizedString(forKey: key, value: nil, table: nil)
    var string = Bundle.main.localizedString(forKey: key, value: defaultValue, table: nil)
    if !values.isEmpty {
        string = String(format: string, locale: Locale.current, arguments: values)
    }
    return string
}

public func R2LocalizedString(_ key: String, in bundleID: String, _ values: CVarArg...) -> String {
    return R2LocalizedString(key, in: bundleID, values)
}

func R2SharedLocalizedString(_ key: String, _ values: CVarArg...) -> String {
    return R2LocalizedString("R2Shared.\(key)", in: Bundle.module, values)
}
