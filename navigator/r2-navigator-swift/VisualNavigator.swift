//
//  VisualNavigator.swift
//  r2-navigator-swift
//
//  Created by Mickaël Menu on 06.05.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import R2Shared


/// A navigator rendering the publication visually on-screen.
public protocol VisualNavigator: Navigator {
    
    /// Viewport view.
    var view: UIView! { get }
    
    /// Current reading progression direction.
    var readingProgression: ReadingProgression { get }
    
    /// Moves to the left content portion (eg. page) relative to the reading progression direction.
    /// - Parameter completion: Called when the transition is completed.
    /// - Returns: Whether the navigator is able to move to the previous content portion. The completion block is only called if true was returned.
    @discardableResult
    func goLeft(animated: Bool, completion: @escaping () -> Void) -> Bool
    
    /// Moves to the right content portion (eg. page) relative to the reading progression direction.
    /// - Parameter completion: Called when the transition is completed.
    /// - Returns: Whether the navigator is able to move to the previous content portion. The completion block is only called if true was returned.
    @discardableResult
    func goRight(animated: Bool, completion: @escaping () -> Void) -> Bool

}

public extension VisualNavigator {
    
    @discardableResult
    func goLeft(animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        switch readingProgression {
        case .ltr, .ttb, .auto:
            return goBackward(animated: animated, completion: completion)
        case .rtl, .btt:
            return goForward(animated: animated, completion: completion)
        }
    }
    
    @discardableResult
    func goRight(animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        switch readingProgression {
        case .ltr, .ttb, .auto:
            return goForward(animated: animated, completion: completion)
        case .rtl, .btt:
            return goBackward(animated: animated, completion: completion)
        }
    }
    
}


public protocol VisualNavigatorDelegate: NavigatorDelegate {

    /// Called when the user tapped the publication, and it didn't trigger any internal action.
    /// The point is relative to the navigator's view.
    func navigator(_ navigator: VisualNavigator, didTapAt point: CGPoint)
    
}

public extension VisualNavigatorDelegate {
    
    func navigator(_ navigator: VisualNavigator, didTapAt point: CGPoint) {
        // Optional
    }
    
}
