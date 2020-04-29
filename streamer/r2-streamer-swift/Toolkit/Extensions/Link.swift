//
//  Link.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 25/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

extension Array where Element == Link {
        
    func first(withType type: MediaType, recursively: Bool = false) -> Link? {
        return first(recursively: recursively) { link in
            // Checks that the link's type is contained by the given `type`.
            link.type.map { type.contains($0) } ?? false
        }
    }

    func filter(byType type: MediaType) -> Self {
        return filter { link in
            // Checks that the link's type is contained by the given `type`.
            link.type.map { type.contains($0) } ?? false
        }
    }
    
}
