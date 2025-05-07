//
//  Copyright 2025 Readium Foundation. All rights reserved.
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

    private let tapEdges: TapEdges
    private let handleTapsWhileScrolling: Bool
    private let minimumHorizontalEdgeSize: Double
    private let horizontalEdgeThresholdPercent: Double?
    private let minimumVerticalEdgeSize: Double
    private let verticalEdgeThresholdPercent: Double?
    private let animatedTransition: Bool

    private weak var navigator: VisualNavigator?

    /// Initializes a new `DirectionalNavigationAdapter`.
    ///
    /// - Parameters:
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
        tapEdges: TapEdges = .horizontal,
        handleTapsWhileScrolling: Bool = false,
        minimumHorizontalEdgeSize: Double = 80.0,
        horizontalEdgeThresholdPercent: Double? = 0.3,
        minimumVerticalEdgeSize: Double = 80.0,
        verticalEdgeThresholdPercent: Double? = 0.3,
        animatedTransition: Bool = false
    ) {
        self.tapEdges = tapEdges
        self.handleTapsWhileScrolling = handleTapsWhileScrolling
        self.minimumHorizontalEdgeSize = minimumHorizontalEdgeSize
        self.horizontalEdgeThresholdPercent = horizontalEdgeThresholdPercent
        self.minimumVerticalEdgeSize = minimumVerticalEdgeSize
        self.verticalEdgeThresholdPercent = verticalEdgeThresholdPercent
        self.animatedTransition = animatedTransition
    }

    /// Binds the adapter to the given visual navigator.
    ///
    /// It will automatically observe pointer and key events to turn pages.
    public func bind(to navigator: VisualNavigator) {
        navigator.addObserver(.tap { [self, weak navigator] event in
            guard let navigator = navigator else {
                return false
            }
            return await onTap(at: event.location, in: navigator)
        })

        navigator.addObserver(.key { [self, weak navigator] event in
            guard let navigator = navigator else {
                return false
            }
            return await onKey(event, in: navigator)
        })
    }

    @MainActor
    private func onTap(at point: CGPoint, in navigator: VisualNavigator) async -> Bool {
        guard handleTapsWhileScrolling || !navigator.presentation.scroll else {
            return false
        }

        let bounds = navigator.view.bounds
        let options = NavigatorGoOptions(animated: animatedTransition)

        if tapEdges.contains(.horizontal) {
            let horizontalEdgeSize = horizontalEdgeThresholdPercent
                .map { max(minimumHorizontalEdgeSize, $0 * bounds.width) }
                ?? minimumHorizontalEdgeSize
            let leftRange = 0.0 ... horizontalEdgeSize
            let rightRange = (bounds.width - horizontalEdgeSize) ... bounds.width

            if rightRange.contains(point.x) {
                return await navigator.goRight(options: options)
            } else if leftRange.contains(point.x) {
                return await navigator.goLeft(options: options)
            }
        }

        if tapEdges.contains(.vertical) {
            let verticalEdgeSize = verticalEdgeThresholdPercent
                .map { max(minimumVerticalEdgeSize, $0 * bounds.height) }
                ?? minimumVerticalEdgeSize
            let topRange = 0.0 ... verticalEdgeSize
            let bottomRange = (bounds.height - verticalEdgeSize) ... bounds.height

            if bottomRange.contains(point.y) {
                return await navigator.goForward(options: options)
            } else if topRange.contains(point.y) {
                return await navigator.goBackward(options: options)
            }
        }

        return false
    }

    private func onKey(_ event: KeyEvent, in navigator: VisualNavigator) async -> Bool {
        guard event.modifiers.isEmpty else {
            return false
        }

        let options = NavigatorGoOptions(animated: animatedTransition)

        switch event.key {
        case .arrowUp:
            return await navigator.goBackward(options: options)
        case .arrowDown, .space:
            return await navigator.goForward(options: options)
        case .arrowLeft:
            return await navigator.goLeft(options: options)
        case .arrowRight:
            return await navigator.goRight(options: options)
        default:
            return false
        }
    }

    @available(*, deprecated, message: "Use the initializer without the navigator parameter and call `bind(to:)`. See the migration guide.")
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

    @available(*, deprecated, message: "Use `bind(to:)` instead of notifying the event yourself. See the migration guide.")
    @MainActor
    @discardableResult
    public func didTap(at point: CGPoint) async -> Bool {
        guard let navigator = navigator else {
            return false
        }
        return await onTap(at: point, in: navigator)
    }

    @available(*, deprecated, message: "Use `bind(to:)` instead of notifying the event yourself. See the migration guide.")
    @discardableResult
    public func didPressKey(event: KeyEvent) async -> Bool {
        guard let navigator = navigator else {
            return false
        }
        return await onKey(event, in: navigator)
    }
}
