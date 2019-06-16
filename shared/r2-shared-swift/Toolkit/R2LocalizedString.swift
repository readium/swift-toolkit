//
//  R2LocalizedString.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 13.06.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Returns the localized string in the main bundle, or fallback on the bundle with given ID if not found.
/// Can be used to override framework localized strings in the host app.
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
    return R2LocalizedString("R2Shared.\(key)", in: "org.readium.r2-shared-swift", values)
}
