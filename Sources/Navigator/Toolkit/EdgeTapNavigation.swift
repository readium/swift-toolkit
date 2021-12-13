//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit

/// Convenience utility to handle page turns when tapping the edge of the screen.
///
/// Call `didTap(at:)` from the `VisualNavigatorDelegate.navigator(_:,didTapAt:)` callback to turn pages
/// automatically.
public final class EdgeTapNavigation {
    /// Navigator used to turn pages.
    private let navigator: VisualNavigator
    
    /// The minimum edge dimension triggering page turns, in pixels.
    private let minimumEdgeSize: Double
    
    /// The percentage of the viewport dimension used to compute the edge dimension. When null, `minimumEdgeSize` will be used instead.
    private let edgeThresholdPercent: Double?
    
    /// animatedTransition Indicates whether the page turns should be animated.
    private let animatedTransition: Bool
    
    public init(
        navigator: VisualNavigator,
        minimumEdgeSize: Double = 80.0,
        edgeThresholdPercent: Double? = 0.3,
        animatedTransition: Bool = false
    ) {
        self.navigator = navigator
        self.minimumEdgeSize = minimumEdgeSize
        self.edgeThresholdPercent = edgeThresholdPercent
        self.animatedTransition = animatedTransition
    }
    
    private enum Transition {
        case forward, backward, none

        func reversed() -> Transition {
            switch self {
            case .forward:
                return .backward
            case .backward:
                return .forward
            case .none:
                return .none
            }
        }
    }

    /// Handles a tap in the navigator viewport and returns whether it was successful.
    /// To be called from  `VisualNavigatorDelegate.navigator(_:,didTapAt:)`.
    public func didTap(at point: CGPoint) -> Bool {
        let bounds = navigator.view.bounds
        let horizontalEdgeSize = edgeThresholdPercent.map { max(minimumEdgeSize, $0 * bounds.width) }
            ?? minimumEdgeSize
        let leftRange = 0.0...horizontalEdgeSize
        let rightRange = (bounds.width - horizontalEdgeSize)...bounds.width
        
        let verticalEdgeSize = edgeThresholdPercent.map { max(minimumEdgeSize, $0 * bounds.height) }
            ?? minimumEdgeSize
        let topRange = 0.0...verticalEdgeSize
        let bottomRange = (bounds.height - verticalEdgeSize)...bounds.height

        let isHorizontal = [.ltr, .rtl, .auto].contains(navigator.readingProgression)
        let isReverse = [.rtl, .btt].contains(navigator.readingProgression)

        var transition: Transition = {
            if isHorizontal {
                if rightRange.contains(point.x) {
                    return .forward
                } else if leftRange.contains(point.x) {
                    return .backward
                }
            } else {
                if bottomRange.contains(point.y) {
                    return .forward
                } else if topRange.contains(point.y) {
                    return .backward
                }
            }
            return .none
        }()

        if isReverse {
            transition = transition.reversed()
        }

        switch transition {
        case .forward:
            return navigator.goForward(animated: animatedTransition)
        case .backward:
            return navigator.goBackward(animated: animatedTransition)
        case .none:
            return false
        }
    }
}
