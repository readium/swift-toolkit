//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import XCTest

func toJSON<T: Encodable>(_ object: T) -> String? {
    let jsonEncoder = JSONEncoder()
    jsonEncoder.outputFormatting.insert(.sortedKeys)
    guard let jsonData = try? jsonEncoder.encode(object),
          let json = String(data: jsonData, encoding: .utf8)
    else {
        return "{}"
    }

    return json
}
