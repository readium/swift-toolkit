//
//  Disjunction.swift
//  r2-navigator-swift
//
//  Created by Winnie Quinn, Alexandre Camilleri on 8/23/17.
//  Copyright © 2017 Readium.
//  This file is covered by the LICENSE file in the root of this project.
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
