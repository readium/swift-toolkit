//
//  Created by Mickaël Menu on 28.01.19.
//  Copyright © 2019 Readium. All rights reserved.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

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
