//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
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

    /// Returns the `Locator` to the first content element that begins on the current screen.
    func firstVisibleElementLocator(completion: @escaping (Locator?) -> Void)
}

public extension VisualNavigator {

    func firstVisibleElementLocator(completion: @escaping (Locator?) -> ()) {
        DispatchQueue.main.async {
            completion(currentLocation)
        }
    }

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
    
    /// Called when the user pressed a key down and it was not handled by the resource.
    func navigator(_ navigator: VisualNavigator, didPressKey event: KeyEvent)
    
    /// Called when the user released a key and it was not handled by the resource.
    func navigator(_ navigator: VisualNavigator, didReleaseKey event: KeyEvent)
}

public extension VisualNavigatorDelegate {
    
    func navigator(_ navigator: VisualNavigator, didTapAt point: CGPoint) {
        // Optional
    }
    
    func navigator(_ navigator: VisualNavigator, didPressKey event: KeyEvent) {
        // Optional
    }
    
    func navigator(_ navigator: VisualNavigator, didReleaseKey event: KeyEvent) {
        // Optional
    }
}
