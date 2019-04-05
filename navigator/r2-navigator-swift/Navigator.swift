//
//  Navigator.swift
//  r2-navigator-swift
//
//  Created by Mickaël Menu on 25.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import SafariServices
import R2Shared


public protocol Navigator {
    
    /// Publication being read.
    var publication: Publication { get }
    
    /// Current position in the publication.
    var currentLocation: Locator? { get }
    
    /// Locators to each synthetic page.
    /// Can be used to implement features such as:
    ///  - displaying the current page and the total number of pages
    ///  - jumping to a given page number
    var positionList: [Locator] { get }

    /// Moves to the position in the publication correponding to the given `Locator`.
    /// - Parameter completion: Called when the transition is completed.
    /// - Returns: Whether the navigator is able to move to the locator. The completion block is only called if true was returned.
    @discardableResult
    func go(to locator: Locator, animated: Bool, completion: @escaping () -> Void) -> Bool
    
    /// Moves to the next content portion (eg. page) in the reading progression direction.
    /// - Parameter completion: Called when the transition is completed.
    /// - Returns: Whether the navigator is able to move to the next content portion. The completion block is only called if true was returned.
    @discardableResult
    func goForward(animated: Bool, completion: @escaping () -> Void) -> Bool
    
    /// Moves to the previous content portion (eg. page) in the reading progression direction.
    /// - Parameter completion: Called when the transition is completed.
    /// - Returns: Whether the navigator is able to move to the previous content portion. The completion block is only called if true was returned.
    @discardableResult
    func goBackward(animated: Bool, completion: @escaping () -> Void) -> Bool
    
}

public extension Navigator {
    
    @discardableResult
    func go(to locator: Locator, animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        return go(to: locator, animated: animated, completion: completion)
    }
    
    @discardableResult
    func goForward(animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        return goForward(animated: animated, completion: completion)
    }
    
    @discardableResult
    func goBackward(animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        return goBackward(animated: animated, completion: completion)
    }
    
}


public enum NavigatorError: LocalizedError {
    /// The user tried to copy the text selection but the DRM License doesn't allow it.
    case copyForbidden
    
    public var errorDescription: String? {
        switch self {
        case .copyForbidden:
            return "You exceeded the amount of characters allowed to be copied."
        }
    }
}
