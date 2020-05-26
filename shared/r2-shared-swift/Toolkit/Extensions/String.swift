//
//  String.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 30/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

extension String {
    
    /// Returns a copy of the string after removing the given `prefix`, when present.
    public func removingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else {
            return self
        }
        return String(dropFirst(prefix.count))
    }

}
