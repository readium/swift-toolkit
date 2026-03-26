//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public enum JSONError: Error {
    case parsing(Any.Type)
    case serializing(Any.Type)
}

// MARK: - JSON Serialization

public func serializeJSONString(_ object: JSONValueEncodable) -> String? {
    let json = object.jsonValue

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

    guard let data = try? encoder.encode(json),
          let string = String(data: data, encoding: .utf8)
    else {
        return nil
    }

    return string
}

public func serializeJSONData(_ object: JSONValueEncodable) -> Data? {
    let json = object.jsonValue

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

    return try? encoder.encode(json)
}
