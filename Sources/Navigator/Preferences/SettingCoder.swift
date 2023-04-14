//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// JSON serializer for a `Setting`.
public struct SettingCoder<Value> {
    public let decode: (Any) -> Value?
    public let encode: (Value) -> Any

    /// Creates a `SettingCoder` which will use the value itself as the encoded value.
    public static func literal<V>() -> SettingCoder<V> {
        SettingCoder<V>(
            decode: { $0 as? V },
            encode: { $0 }
        )
    }

    /// Creates a `SettingCoder` for a value implementing `RawRepresentable` to encode it.
    public static func rawValue<V: RawRepresentable>() -> SettingCoder<V> {
        SettingCoder<V>(
            decode: { ($0 as? V.RawValue).flatMap(V.init(rawValue:)) },
            encode: { $0.rawValue }
        )
    }
}
