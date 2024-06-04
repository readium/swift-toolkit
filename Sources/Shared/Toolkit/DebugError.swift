//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public struct DebugError: Error, CustomStringConvertible {
    public let message: String
    
    public init(_ message: String) {
        self.message = message
    }
    
    public var description: String {
        "DebugError(\(message))"
    }
}
