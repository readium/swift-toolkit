//
//  Resource.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 11/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
@testable import R2Shared

extension ResourceError: Equatable {
    
    public static func == (lhs: ResourceError, rhs: ResourceError) -> Bool {
        switch (lhs, rhs) {
        case (.notFound, .notFound),
             (.forbidden, .forbidden),
             (.unavailable, .unavailable):
            return true
        case (.other(let lerr), .other(let rerr)) where lerr.localizedDescription == rerr.localizedDescription:
            return true
        default:
            return false
        }
    }

}
