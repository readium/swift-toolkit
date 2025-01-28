//
//  UInt64.swift
//  Readium
//
//  Created by Mickaël on 1/28/25.
//

public extension UInt64 {
    func ceilMultiple(of divisor: UInt64) -> UInt64 {
        divisor * (self / divisor + ((self % divisor == 0) ? 0 : 1))
    }

    func floorMultiple(of divisor: UInt64) -> UInt64 {
        divisor * (self / divisor)
    }
}
