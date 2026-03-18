//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import UIKit

/// Adopted by view controllers participating in the image preview custom
/// transition to set up their initial state and animate property changes.
protocol ImagePreviewTransitioning {
    /// Called before the animation begins to set the initial layout state.
    func prepareForTransition(isPresenting: Bool)
    /// Called inside the animation block to apply the target layout state.
    func performTransition(isPresenting: Bool)
}

// MARK: - Transition

/// A single animator that handles both presentation and dismissal.
///
/// When presenting, it animates the image from its source frame (position
/// in the navigator) to the centered, aspect-fitted target frame while
/// fading in the chrome. When dismissing, it reverses the animation.
final class ImagePreviewTransition: NSObject, UIViewControllerAnimatedTransitioning {
    let isPresenting: Bool
    let animator: UIViewPropertyAnimator

    init(isPresenting: Bool) {
        self.isPresenting = isPresenting
        let initialVelocity = CGVector(dx: 0.5, dy: 0.5)
        let timing = UISpringTimingParameters(dampingRatio: 0.85, initialVelocity: initialVelocity)
        animator = UIViewPropertyAnimator(duration: 0.35, timingParameters: timing)
    }

    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        animator.duration
    }

    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        let animatedView = transitionContext.view(forKey: isPresenting ? .to : .from)!
        let transitioning = transitionContext.viewController(forKey: isPresenting ? .to : .from) as! ImagePreviewTransitioning
        let containerView = transitionContext.containerView

        if isPresenting {
            animatedView.frame = containerView.bounds
            containerView.addSubview(animatedView)
            animatedView.layoutIfNeeded()
        } else if let toView = transitionContext.view(forKey: .to) {
            // With .fullScreen the presenting view was removed after
            // presentation. Re-add it behind so it's visible during dismiss.
            containerView.insertSubview(toView, belowSubview: animatedView)
        }

        transitioning.prepareForTransition(isPresenting: isPresenting)

        animator.addAnimations { [isPresenting] in
            transitioning.performTransition(isPresenting: isPresenting)
        }

        animator.addCompletion { [isPresenting] position in
            let didComplete = position == .end && !transitionContext.transitionWasCancelled
            if !isPresenting, didComplete {
                animatedView.removeFromSuperview()
            }
            transitionContext.completeTransition(didComplete)
        }

        animator.startAnimation()
    }
}
