//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// An alternate identifier for a publication, i.e. an identifier other than the
/// primary ``Metadata/identifier``.
///
/// https://readium.org/webpub-manifest/contexts/default/#identifier
/// https://readium.org/webpub-manifest/schema/altIdentifier.schema.json
public struct AltIdentifier: Hashable, Sendable, JSONValueDecodable, JSONValueEncodable {
    /// The identifier value.
    public var value: String

    /// URI of the identifier's scheme, when known (e.g. `urn:isbn`).
    public var scheme: String?

    public init(value: String, scheme: String? = nil) {
        self.value = value
        self.scheme = scheme
    }

    /// Parses an ``AltIdentifier`` from its RWPM JSON representation, which is
    /// either a bare URI string or an object carrying a `value` and an optional
    /// `scheme`.
    public init?<T: JSONValueEncodable>(json: T?, warnings: WarningLogger?) throws {
        guard let json = json?.jsonValue else {
            return nil
        }

        if let value = json.string {
            self.init(value: value)
        } else if let object = json.object, let value = object["value"]?.string {
            self.init(value: value, scheme: object["scheme"]?.string)
        } else {
            warnings?.log("Invalid AltIdentifier object", model: Self.self, source: json, severity: .minor)
            throw JSONError.parsing(Self.self)
        }
    }

    /// Serializes to a bare string when no scheme is set – the schema's compact
    /// form – or to an object otherwise.
    public var jsonValue: JSONValue {
        guard let scheme = scheme else {
            return .string(value)
        }
        return .object([
            "value": .string(value),
            "scheme": .string(scheme),
        ])
    }
}
