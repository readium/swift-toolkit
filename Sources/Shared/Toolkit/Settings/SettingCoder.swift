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

    public static func literal<V>() -> SettingCoder<V> {
        SettingCoder<V>(
            decode: { $0 as? V },
            encode: { $0 }
        )
    }

    public static func rawValue<V: RawRepresentable>() -> SettingCoder<V> {
        SettingCoder<V>(
            decode: { ($0 as? V.RawValue).flatMap(V.init(rawValue:)) },
            encode: { $0.rawValue }
        )
    }
}

/*
extension SettingCoder {
    public func eraseToAnySettingCoder() -> AnySettingCoder<Value> {
        AnySettingCoder(self)
    }
}

public class AnySettingCoder<Value>: SettingCoder {

    private let decoder: (Any) -> Value?
    private let encoder: (Value) -> Any

    init<Coder: SettingCoder>(_ coder: Coder) where Coder.Value == Value {
        self.decoder = coder.decode
        self.encoder = coder.encode
    }
    public func decode(_ json: Any) -> Value? {
        decoder(json)
    }

    public func encode(_ value: Value) -> Any {
       encoder(value)
    }
}
 */