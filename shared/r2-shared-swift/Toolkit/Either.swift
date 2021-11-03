//
//  Either.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 18.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


public enum Either<L, R> {
    case left(L)
    case right(R)
}


extension Either: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .left(let l):
            return "Either.left(\(l))"
        case .right(let r):
            return "Either.right(\(r))"
        }
    }
    
}
