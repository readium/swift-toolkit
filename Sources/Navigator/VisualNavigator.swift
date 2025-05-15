//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UIKit

/// A navigator rendering the publication visually on-screen.
public protocol VisualNavigator: Navigator, InputObservable {
    /// Viewport view.
    var view: UIView! { get }

    /// Current presentation rendered by the navigator.
    var presentation: VisualNavigatorPresentation { get }

    /// Moves to the left content portion (eg. page) relative to the reading
    /// progression direction.
    ///
    /// - Parameter completion: Called when the transition is completed.
    /// - Returns: Whether the navigator is able to move to the previous
    ///   content portion. The completion block is only called if true was
    ///   returned.
    @discardableResult
    func goLeft(options: NavigatorGoOptions) async -> Bool

    /// Moves to the right content portion (eg. page) relative to the reading
    /// progression direction.
    ///
    /// - Parameter completion: Called when the transition is completed.
    /// - Returns: Whether the navigator is able to move to the previous
    ///   content portion. The completion block is only called if true was
    ///   returned.
    @discardableResult
    func goRight(options: NavigatorGoOptions) async -> Bool

    /// Returns the `Locator` to the first content element that begins on the
    /// current screen.
    func firstVisibleElementLocator() async -> Locator?
}

public extension VisualNavigator {
    func firstVisibleElementLocator() async -> Locator? {
        currentLocation
    }

    @discardableResult
    func goLeft(options: NavigatorGoOptions) async -> Bool {
        switch presentation.readingProgression {
        case .ltr:
            return await goBackward(options: options)
        case .rtl:
            return await goForward(options: options)
        }
    }

    @discardableResult
    func goRight(options: NavigatorGoOptions) async -> Bool {
        switch presentation.readingProgression {
        case .ltr:
            return await goForward(options: options)
        case .rtl:
            return await goBackward(options: options)
        }
    }
}

public struct VisualNavigatorPresentation {
    /// Horizontal direction of progression across resources.
    public let readingProgression: ReadingProgression

    /// If the overflow of the content is managed through scroll instead of
    /// pagination.
    public let scroll: Bool

    /// Main axis along which the resources are laid out.
    public let axis: Axis

    public init(readingProgression: ReadingProgression, scroll: Bool, axis: Axis) {
        self.readingProgression = readingProgression
        self.scroll = scroll
        self.axis = axis
    }
}

@MainActor public protocol VisualNavigatorDelegate: NavigatorDelegate {
    /// Called when the navigator presentation changed, for example after
    /// applying a new set of preferences.
    func navigator(_ navigator: Navigator, presentationDidChange presentation: VisualNavigatorPresentation)

    /// Called when the user tapped the publication, and it didn't trigger any
    /// internal action. The point is relative to the navigator's view.
    func navigator(_ navigator: VisualNavigator, didTapAt point: CGPoint)

    /// Called when the user pressed a key down and it was not handled by the
    /// resource.
    func navigator(_ navigator: VisualNavigator, didPressKey event: KeyEvent)

    /// Called when the user released a key and it was not handled by the
    /// resource.
    func navigator(_ navigator: VisualNavigator, didReleaseKey event: KeyEvent)

    /// Called when the user taps on an internal link.
    ///
    /// Return `true` to navigate to the link, or `false` if you intend to
    /// present the link yourself
    func navigator(_ navigator: VisualNavigator, shouldNavigateToLink link: Link) -> Bool
}

public extension VisualNavigatorDelegate {
    func navigator(_ navigator: Navigator, presentationDidChange presentation: VisualNavigatorPresentation) {
        // Optional
    }

    func navigator(_ navigator: VisualNavigator, didTapAt point: CGPoint) {
        // Optional
    }

    func navigator(_ navigator: VisualNavigator, didPressKey event: KeyEvent) {
        // Optional
    }

    func navigator(_ navigator: VisualNavigator, didReleaseKey event: KeyEvent) {
        // Optional
    }

    func navigator(_ navigator: VisualNavigator, shouldNavigateToLink link: Link) -> Bool {
        true
    }
}
