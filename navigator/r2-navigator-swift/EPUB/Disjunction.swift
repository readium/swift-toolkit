//
//  Disjunction.swift
//  r2-navigator-swift
//
//  Created by Winnie Quinn, Alexandre Camilleri on 8/23/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

enum Disjunction<A, B> {
    case first(value: A)
    case second(value: B)
    case both(first: A, second: B)

    var count: Int {
        switch self {
        case .first:
            return 1
        case .second:
            return 1
        case .both:
            return 2
        }
    }
}
