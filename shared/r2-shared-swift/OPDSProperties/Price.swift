//
//  Price.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 10/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

public class Price {
    public var currency: String
    public var value: Double
    
    public init(currency: String, value: Double) {
        self.currency = currency
        self.value = value
    }
}
