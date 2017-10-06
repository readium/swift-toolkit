//
//  Drm.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 10/5/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation


public struct Drm {
    public let brand: Brand
    public let scheme: Scheme
    public var decypher: ((Data) -> Data)?

    public enum Brand {
        case lcp
    }

    public enum Scheme: String {
        case lcp = "http://readium.org/2014/01/lcp"
    }

    public init(brand: Brand) {
        self.brand = brand
        switch brand {
        case .lcp:
            scheme = .lcp
        }
    }
}
