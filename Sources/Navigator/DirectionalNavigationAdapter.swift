//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreGraphics
import Foundation

/// Helper handling directional UI events (e.g. edge taps or arrow keys) to turn
/// the pages of a `VisualNavigator`.
///
/// This takes into account the reading progression of the navigator to turn
/// pages in the right direction.
public final class DirectionalNavigationAdapter {
    /// Indicates which viewport edges trigger page turns on tap.
    public struct TapEdges: OptionSet {
        /// The user can turn pages when tapping on the edges of both the
        /// horizontal and vertical axes.
        public static let all: TapEdges = [.horizontal, .vertical]
        /// The user can turn pages when tapping on the left and right edges.
        public static let horizontal = TapEdges(rawValue: 1 << 0)
        /// The user can turn pages when tapping on the top and bottom edges.
        public static let vertical = TapEdges(rawValue: 1 << 1)

        public var rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    private weak var navigator: VisualNavigator?
    private let tapEdges: TapEdges
    private let handleTapsWhileScrolling: Bool
    private let minimumHorizontalEdgeSize: Double
    private let horizontalEdgeThresholdPercent: Double?
    private let minimumVerticalEdgeSize: Double
    private let verticalEdgeThresholdPercent: Double?
    private let animatedTransition: Bool

    /// Initializes a new `DirectionalNavigationAdapter`.
    ///
    /// - Parameters:
    ///  - navigator: Navigator used to turn pages.
    ///  - tapEdges: Indicates which viewport edges handle taps.
    ///  - handleTapsWhileScrolling: Indicates whether the page turns should be
    ///    handled when the publication is scrollable.
    ///  - minimumHorizontalEdgeSize: The minimum horizontal edge dimension
    ///    triggering page turns, in pixels.
    ///  - horizontalEdgeThresholdPercent: The percentage of the viewport
    ///    dimension used to compute the horizontal edge size. When null,
    ///    `minimumHorizontalEdgeSize` will be used instead.
    ///  - minimumVerticalEdgeSize: The minimum vertical edge dimension
    ///    triggering page turns, in pixels.
    ///  - verticalEdgeThresholdPercent: The percentage of the viewport
    ///    dimension used to compute the vertical edge size. When null,
    ///    `minimumVerticalEdgeSize` will be used instead.
    ///  - animatedTransition: Indicates whether the page turns should be
    ///    animated.
    public init(
        navigator: VisualNavigator,
        tapEdges: TapEdges = .horizontal,
        handleTapsWhileScrolling: Bool = false,
        minimumHorizontalEdgeSize: Double = 80.0,
        horizontalEdgeThresholdPercent: Double? = 0.3,
        minimumVerticalEdgeSize: Double = 80.0,
        verticalEdgeThresholdPercent: Double? = 0.3,
        animatedTransition: Bool = false
    ) {
        self.navigator = navigator
        self.tapEdges = tapEdges
        self.handleTapsWhileScrolling = handleTapsWhileScrolling
        self.minimumHorizontalEdgeSize = minimumHorizontalEdgeSize
        self.horizontalEdgeThresholdPercent = horizontalEdgeThresholdPercent
        self.minimumVerticalEdgeSize = minimumVerticalEdgeSize
        self.verticalEdgeThresholdPercent = verticalEdgeThresholdPercent
        self.animatedTransition = animatedTransition
    }

    /// Turn pages when `point` is located in one of the tap edges.
    ///
    /// To be called from `VisualNavigatorDelegate.navigator(_:didTapAt:)`.
    ///
    /// - Parameter point: Tap point in the navigator bounds.
    /// - Returns: Whether the tap triggered a page turn.
    @discardableResult
    public func didTap(at point: CGPoint) -> Bool {
        guard
            let navigator = navigator,
            handleTapsWhileScrolling || !navigator.presentation.scroll
        else {
            return false
        }

        let bounds = navigator.view.bounds

        if tapEdges.contains(.horizontal) {
            let horizontalEdgeSize = horizontalEdgeThresholdPercent
                .map { max(minimumHorizontalEdgeSize, $0 * bounds.width) }
                ?? minimumHorizontalEdgeSize
            let leftRange = 0.0 ... horizontalEdgeSize
            let rightRange = (bounds.width - horizontalEdgeSize) ... bounds.width

            if rightRange.contains(point.x) {
                return navigator.goRight(animated: animatedTransition)
            } else if leftRange.contains(point.x) {
                return navigator.goLeft(animated: animatedTransition)
            }
        }

        if tapEdges.contains(.vertical) {
            let verticalEdgeSize = verticalEdgeThresholdPercent
                .map { max(minimumVerticalEdgeSize, $0 * bounds.height) }
                ?? minimumVerticalEdgeSize
            let topRange = 0.0 ... verticalEdgeSize
            let bottomRange = (bounds.height - verticalEdgeSize) ... bounds.height

            if bottomRange.contains(point.y) {
                return navigator.goForward(animated: animatedTransition)
            } else if topRange.contains(point.y) {
                return navigator.goBackward(animated: animatedTransition)
            }
        }

        return false
    }

    /// Turn pages when the arrow or space keys are used.
    ///
    /// To be called from `VisualNavigatorDelegate.navigator(_:didPressKey:)`
    ///
    /// - Returns: Whether the key press triggered a page turn.
    @discardableResult
    public func didPressKey(event: KeyEvent) -> Bool {
        guard
            let navigator = navigator,
            event.modifiers.isEmpty
        else {
            return false
        }

        switch event.key {
        case .arrowUp:
            return navigator.goBackward(animated: animatedTransition)
        case .arrowDown, .space:
            return navigator.goForward(animated: animatedTransition)
        case .arrowLeft:
            return navigator.goLeft(animated: animatedTransition)
        case .arrowRight:
            return navigator.goRight(animated: animatedTransition)
        default:
            return false
        }
    }
}
