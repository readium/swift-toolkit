//
//  Price.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 10/27/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Price related to a publication
public class Price {
    public var currency: String
    public var value: Double
    
    public init(currency: String, value: Double) {
        self.currency = currency
        self.value = value
    }
}
