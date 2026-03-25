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

public func serializeJSONString(_ object: Any) -> String? {
    let unwrappedObject = JSONValue(object)?.any ?? object

    guard
        JSONSerialization.isValidJSONObject(unwrappedObject),
        let data = try? JSONSerialization.data(withJSONObject: unwrappedObject, options: .sortedKeys),
        let string = String(data: data, encoding: .utf8)
    else {
        return nil
    }

    // Unescapes slashes
    return string.replacingOccurrences(of: "\\/", with: "/")
}

public func serializeJSONData(_ object: Any) -> Data? {
    guard let string = serializeJSONString(object) else {
        return nil
    }
    return string.data(using: .utf8)
}
