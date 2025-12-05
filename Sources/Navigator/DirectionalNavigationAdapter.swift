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
    @available(*, deprecated, renamed: "Edges")
    public typealias TapEdges = Edges

    /// Indicates which viewport edges trigger page turns on pointer activation.
    public struct Edges: OptionSet {
        /// The user can turn pages when tapping on the edges of both the
        /// horizontal and vertical axes.
        public static let all: Edges = [.horizontal, .vertical]
        /// The user can turn pages when tapping on the left and right edges.
        public static let horizontal = Edges(rawValue: 1 << 0)
        /// The user can turn pages when tapping on the top and bottom edges.
        public static let vertical = Edges(rawValue: 1 << 1)

        public var rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    public struct PointerPolicy {
        /// The types of pointer that will trigger page turns.
        public var types: [PointerType]

        /// Indicates which viewport edges recognize pointer activation.
        public var edges: Edges

        /// Indicates whether to ignore pointer events when the publication is
        /// scrollable.
        public var ignoreWhileScrolling: Bool

        /// The minimum horizontal edge dimension that triggers page turns, in
        /// pixels.
        public var minimumHorizontalEdgeSize: Double

        /// The percentage of the viewport dimension used to calculate the
        /// horizontal edge size. If it is nil, a fixed edge of
        /// `minimumHorizontalEdgeSize` will be used instead.
        public var horizontalEdgeThresholdPercent: Double?

        /// The minimum vertical edge dimension that triggers page turns, in
        /// pixels.
        public var minimumVerticalEdgeSize: Double

        /// The percentage of the viewport dimension used to calculate the
        /// vertical edge size. If it is nil, a fixed edge of
        /// `minimumVerticalEdgeSize` will be used instead.
        public var verticalEdgeThresholdPercent: Double?

        public init(
            types: [PointerType] = [.touch, .mouse],
            edges: Edges = .horizontal,
            ignoreWhileScrolling: Bool = true,
            minimumHorizontalEdgeSize: Double = 80.0,
            horizontalEdgeThresholdPercent: Double? = 0.3,
            minimumVerticalEdgeSize: Double = 80.0,
            verticalEdgeThresholdPercent: Double? = 0.3
        ) {
            self.types = types
            self.edges = edges
            self.ignoreWhileScrolling = ignoreWhileScrolling
            self.minimumHorizontalEdgeSize = minimumHorizontalEdgeSize
            self.horizontalEdgeThresholdPercent = horizontalEdgeThresholdPercent
            self.minimumVerticalEdgeSize = minimumVerticalEdgeSize
            self.verticalEdgeThresholdPercent = verticalEdgeThresholdPercent
        }
    }

    public struct KeyboardPolicy {
        /// Indicates whether arrow keys should turn pages.
        public var handleArrowKeys: Bool

        /// Indicates whether the space key should turn the page forward.
        public var handleSpaceKey: Bool

        public init(
            handleArrowKeys: Bool = true,
            handleSpaceKey: Bool = true
        ) {
            self.handleArrowKeys = handleArrowKeys
            self.handleSpaceKey = handleSpaceKey
        }
    }

    private let pointerPolicy: PointerPolicy
    private let keyboardPolicy: KeyboardPolicy
    private let animatedTransition: Bool

    private weak var navigator: VisualNavigator?

    /// Initializes a new `DirectionalNavigationAdapter`.
    ///
    /// - Parameters:
    ///  - pointerPolicy: Policy on page turns using pointers (touches, mouse).
    ///  - keyboardPolicy: Policy on page turns using the keyboard.
    ///  - animatedTransition: Indicates whether the page turns should be
    ///    animated.
    public init(
        pointerPolicy: PointerPolicy = PointerPolicy(),
        keyboardPolicy: KeyboardPolicy = KeyboardPolicy(),
        animatedTransition: Bool = false
    ) {
        self.pointerPolicy = pointerPolicy
        self.keyboardPolicy = keyboardPolicy
        self.animatedTransition = animatedTransition
    }

    /// Binds the adapter to the given visual navigator.
    ///
    /// It will automatically observe pointer and key events to turn pages.
    @MainActor public func bind(to navigator: VisualNavigator) {
        for pointerType in PointerType.allCases {
            guard pointerPolicy.types.contains(pointerType) else {
                continue
            }

            switch pointerType {
            case .touch:
                navigator.addObserver(.tap { [self, weak navigator] event in
                    guard let navigator = navigator else {
                        return false
                    }
                    return await onTap(at: event.location, in: navigator)
                })
            case .mouse:
                navigator.addObserver(.click { [self, weak navigator] event in
                    guard let navigator = navigator else {
                        return false
                    }
                    return await onTap(at: event.location, in: navigator)
                })
            }
        }

        navigator.addObserver(.key { [self, weak navigator] event in
            guard let navigator = navigator else {
                return false
            }
            return await onKey(event, in: navigator)
        })
    }

    @MainActor
    private func onTap(at point: CGPoint, in navigator: VisualNavigator) async -> Bool {
        guard !pointerPolicy.ignoreWhileScrolling || !navigator.presentation.scroll else {
            return false
        }

        let bounds = navigator.view.bounds
        let options = NavigatorGoOptions(animated: animatedTransition)

        if pointerPolicy.edges.contains(.horizontal) {
            let horizontalEdgeSize = pointerPolicy.horizontalEdgeThresholdPercent
                .map { max(pointerPolicy.minimumHorizontalEdgeSize, $0 * bounds.width) }
                ?? pointerPolicy.minimumHorizontalEdgeSize
            let leftRange = 0.0 ... horizontalEdgeSize
            let rightRange = (bounds.width - horizontalEdgeSize) ... bounds.width

            if rightRange.contains(point.x) {
                return await navigator.goRight(options: options)
            } else if leftRange.contains(point.x) {
                return await navigator.goLeft(options: options)
            }
        }

        if pointerPolicy.edges.contains(.vertical) {
            let verticalEdgeSize = pointerPolicy.verticalEdgeThresholdPercent
                .map { max(pointerPolicy.minimumVerticalEdgeSize, $0 * bounds.height) }
                ?? pointerPolicy.minimumVerticalEdgeSize
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
        case .arrowUp where keyboardPolicy.handleArrowKeys:
            return await navigator.goBackward(options: options)
        case .arrowDown where keyboardPolicy.handleArrowKeys:
            return await navigator.goForward(options: options)
        case .arrowLeft where keyboardPolicy.handleArrowKeys:
            return await navigator.goLeft(options: options)
        case .arrowRight where keyboardPolicy.handleArrowKeys:
            return await navigator.goRight(options: options)
        case .space where keyboardPolicy.handleSpaceKey:
            return await navigator.goForward(options: options)
        default:
            return false
        }
    }

    @available(*, deprecated, message: "Use the new initializer without the navigator parameter and call `bind(to:)`. See the migration guide.")
    public init(
        navigator: VisualNavigator,
        tapEdges: Edges = .horizontal,
        handleTapsWhileScrolling: Bool = false,
        minimumHorizontalEdgeSize: Double = 80.0,
        horizontalEdgeThresholdPercent: Double? = 0.3,
        minimumVerticalEdgeSize: Double = 80.0,
        verticalEdgeThresholdPercent: Double? = 0.3,
        animatedTransition: Bool = false
    ) {
        self.navigator = navigator
        pointerPolicy = PointerPolicy(
            types: [.touch, .mouse],
            ignoreWhileScrolling: !handleTapsWhileScrolling,
            minimumHorizontalEdgeSize: minimumHorizontalEdgeSize,
            horizontalEdgeThresholdPercent: horizontalEdgeThresholdPercent,
            minimumVerticalEdgeSize: minimumVerticalEdgeSize,
            verticalEdgeThresholdPercent: verticalEdgeThresholdPercent
        )
        keyboardPolicy = KeyboardPolicy()
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
