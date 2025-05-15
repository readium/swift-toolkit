//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import ReadiumShared
import SafariServices

public protocol Navigator: AnyObject {
    /// Publication being rendered.
    var publication: Publication { get }

    /// Current position in the publication.
    /// Can be used to save a bookmark to the current position.
    var currentLocation: Locator? { get }

    /// Moves to the position in the publication correponding to the given
    /// `Locator`.
    ///
    /// - Returns: Whether the navigator is able to move to the locator. The
    ///   completion block is only called if true was returned.
    @discardableResult
    func go(to locator: Locator, options: NavigatorGoOptions) async -> Bool

    /// Moves to the position in the publication targeted by the given link.

    /// - Returns: Whether the navigator is able to move to the locator. The
    ///   completion block is only called if true was returned.
    @discardableResult
    func go(to link: Link, options: NavigatorGoOptions) async -> Bool

    /// Moves to the next content portion (eg. page or audiobook resource) in
    /// the reading progression direction.
    ///
    /// - Returns: Whether the navigator is able to move to the next content
    ///   portion. The completion block is only called if true was returned.
    @discardableResult
    func goForward(options: NavigatorGoOptions) async -> Bool

    /// Moves to the previous content portion (eg. page or audiobook resource)
    /// in the reading progression direction.
    ///
    /// - Returns: Whether the navigator is able to move to the previous content
    ///   portion. The completion block is only called if true was returned.
    @discardableResult
    func goBackward(options: NavigatorGoOptions) async -> Bool
}

public struct NavigatorGoOptions {
    /// Indicates whether the move should be animated when possible.
    public var animated: Bool = false

    /// Extension point for navigator implementations.
    public var otherOptions: [String: Any] {
        get { otherOptionsJSON.json }
        set { otherOptionsJSON = JSONDictionary(newValue) ?? JSONDictionary() }
    }

    // Trick to keep the struct equatable despite [String: Any]
    private var otherOptionsJSON: JSONDictionary

    public init(animated: Bool = false, otherOptions: [String: Any] = [:]) {
        self.animated = animated
        otherOptionsJSON = JSONDictionary(otherOptions) ?? JSONDictionary()
    }

    public static var none: NavigatorGoOptions {
        NavigatorGoOptions()
    }

    /// Convenience helper for options that contain only animated: true.
    public static var animated: NavigatorGoOptions {
        NavigatorGoOptions(animated: true)
    }
}

public extension Navigator {
    @discardableResult
    func go(to locator: Locator, options: NavigatorGoOptions = NavigatorGoOptions()) async -> Bool {
        await go(to: locator, options: options)
    }

    @discardableResult
    func go(to link: Link, options: NavigatorGoOptions = NavigatorGoOptions()) async -> Bool {
        await go(to: link, options: options)
    }

    @discardableResult
    func goForward(options: NavigatorGoOptions = NavigatorGoOptions()) async -> Bool {
        await goForward(options: options)
    }

    @discardableResult
    func goBackward(options: NavigatorGoOptions = NavigatorGoOptions()) async -> Bool {
        await goBackward(options: options)
    }
}

@MainActor public protocol NavigatorDelegate: AnyObject {
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

    /// Called when an error occurs while attempting to load a resource.
    func navigator(_ navigator: Navigator, didFailToLoadResourceAt href: RelativeURL, withError error: ReadError)
}

public extension NavigatorDelegate {
    func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {}

    func navigator(_ navigator: Navigator, didJumpTo locator: Locator) {}

    func navigator(_ navigator: Navigator, presentExternalURL url: URL) {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    func navigator(_ navigator: Navigator, shouldNavigateToNoteAt link: Link, content: String, referrer: String?) -> Bool {
        true
    }

    func navigator(_ navigator: Navigator, didFailToLoadResourceAt href: RelativeURL, withError error: ReadError) {}
}

public enum NavigatorError: Error {
    /// The user tried to copy the text selection but the DRM License doesn't allow it.
    case copyForbidden
}
