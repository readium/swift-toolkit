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
    
    /// Current position in the publication.
    /// Can be used to save a bookmark to the current position.
    var currentLocation: Locator? { get }

    /// Moves to the position in the publication correponding to the given `Locator`.
    /// - Parameter completion: Called when the transition is completed.
    /// - Returns: Whether the navigator is able to move to the locator. The completion block is only called if true was returned.
    @discardableResult
    func go(to locator: Locator, animated: Bool, completion: @escaping () -> Void) -> Bool

    /// Moves to the position in the publication targeted by the given link.
    /// - Parameter completion: Called when the transition is completed.
    /// - Returns: Whether the navigator is able to move to the locator. The completion block is only called if true was returned.
    @discardableResult
    func go(to link: Link, animated: Bool, completion: @escaping () -> Void) -> Bool
    
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

    /// Adds default values for the parameters.
    @discardableResult
    func go(to locator: Locator, animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        go(to: locator, animated: animated, completion: completion)
    }
    
    /// Adds default values for the parameters.
    @discardableResult
    func go(to link: Link, animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        go(to: link, animated: animated, completion: completion)
    }
    
    /// Adds default values for the parameters.
    @discardableResult
    func goForward(animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        goForward(animated: animated, completion: completion)
    }
    
    /// Adds default values for the parameters.
    @discardableResult
    func goBackward(animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        goBackward(animated: animated, completion: completion)
    }

}


public protocol NavigatorDelegate: AnyObject {

    /// Called when the current position in the publication changed. You should save the locator here to restore the
    /// last read page.
    func navigator(_ navigator: Navigator, locationDidChange locator: Locator)

    /// Called when the navigator jumps to an explicit location, which might break the linear reading progression.
    ///
    /// For example, it is called when clicking on internal links or programmatically calling `go()`, but not when
    /// turning pages.
    ///
    /// You can use this callback to implement a navigation history by differentiating between continuous and
    /// discontinuous moves.
    func navigator(_ navigator: Navigator, didJumpTo locator: Locator)

    /// Called when an error must be reported to the user.
    func navigator(_ navigator: Navigator, presentError error: NavigatorError)
    
    /// Called when the user tapped an external URL. The default implementation opens the URL with the default browser.
    func navigator(_ navigator: Navigator, presentExternalURL url: URL)
    
    /// Called when the user taps on a link referring to a note.
    ///
    /// Return `true` to navigate to the note, or `false` if you intend to present the
    /// note yourself, using its `content`. `link.type` contains information about the
    /// format of `content` and `referrer`, such as `text/html`.
    func navigator(_ navigator: Navigator, shouldNavigateToNoteAt link: Link, content: String, referrer: String?) -> Bool
    
}


public extension NavigatorDelegate {

    func navigator(_ navigator: Navigator, didJumpTo locator: Locator) {}

    func navigator(_ navigator: Navigator, presentExternalURL url: URL) {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    func navigator(_ navigator: Navigator, shouldNavigateToNoteAt link: Link, content: String, referrer: String?) -> Bool {
        return true
    }
}


public enum NavigatorError: LocalizedError {
    /// The user tried to copy the text selection but the DRM License doesn't allow it.
    case copyForbidden
    
    public var errorDescription: String? {
        switch self {
        case .copyForbidden:
            return R2NavigatorLocalizedString("NavigatorError.copyForbidden")
        }
    }
}
