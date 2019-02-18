//
//  DrmRights.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 18.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// A non-consumable right.
public enum DrmRight {
    /// Displaying the content in the reader.
    case display
    /// Reading the content out loud with a TTS engine.
    case speak
}


/// A consumable right, can be limited by a certain quantity.
public enum DrmConsumableRight {
    /// Printing the content.
    case print
    /// Copying the content for excerpting.
    case copy
}


public enum DrmRightQuantity {
    // This right is forbidden or all consumed.
    case none
    // No limit on the quantity of right that can be consumed.
    case unlimited
    // Number of individual actions (eg. using the Copy button).
    case actions(UInt)
    // Number of characters.
    case characters(UInt)
    // Number of pages.
    case pages(UInt)
}

extension DrmRightQuantity: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .none:
            return "none"
        case .unlimited:
            return "unlimited"
        case .actions(let n):
            return "\(n)"
        case .characters(let n):
            return "\(n) character" + (n > 1 ? "s" : "")
        case .pages(let n):
            return "\(n) page" + (n > 1 ? "s" : "")
        }
    }
    
}

public enum DrmRightError: Error {
    /// This right is forbidden for this license.
    case forbidden
    /// The user tried to consume more than available.
    case exceeded(quantity: DrmRightQuantity)
}


public protocol DrmRights {
    
    /// Returns whether this right is allowed.
    /// The default implementation allows all the rights.
    func can(_ right: DrmRight) -> Bool

    /// Returns whether this consumable right is allowed right now.
    /// The default implementation uses `remaining`.
    func can(_ right: DrmConsumableRight) -> Bool

    /// Returns the amount of quantity left for the given consumable right.
    /// The default implementation has an unlimited quantity for all consumable rights.
    func remainingQuantity(for right: DrmConsumableRight) -> DrmRightQuantity
    
    /// Use the given quantity of the consumable right.
    /// An error might be thrown if the right is not allowed or exceeds the remaining quantitiy.
    /// The default implementation does nothing.
    func consume(_ right: DrmConsumableRight, quantity: DrmRightQuantity?) throws

}

public extension DrmRights {
    
    public func can(_ right: DrmRight) -> Bool {
        return true
    }
    
    public func can(_ right: DrmConsumableRight) -> Bool {
        switch remainingQuantity(for: right) {
        case .none:
            return false
        case .actions(let n), .characters(let n), .pages(let n):
            return n > 0
        case .unlimited:
            return true
        }
    }
    
    public func remainingQuantity(for right: DrmConsumableRight) -> DrmRightQuantity {
        return .unlimited
    }
    
    public func consume(_ right: DrmConsumableRight, quantity: DrmRightQuantity?) throws {
    }
    
}
