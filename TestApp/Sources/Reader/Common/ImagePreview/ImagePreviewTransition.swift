//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import UIKit

protocol ImagePreviewTransitioning {
    func prepareForTransition(isPresenting: Bool)
    func performTransition(isPresenting: Bool)
}

// MARK: - Transition Animator

/// A single animator that handles both presentation and dismissal.
///
/// When presenting, it animates the image from its source frame (position
/// in the navigator) to the centered, aspect-fitted target frame while
/// fading in the chrome. When dismissing, it reverses the animation.
final class ImagePreviewAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let isPresenting: Bool
    let animator: UIViewPropertyAnimator

    init(isPresenting: Bool) {
        self.isPresenting = isPresenting
        let timing = UISpringTimingParameters(dampingRatio: 0.85, initialVelocity: CGVector(dx: 0.5, dy: 0.5))
        animator = UIViewPropertyAnimator(duration: 0.35, timingParameters: timing)
    }

    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        animator.duration
    }

    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        if isPresenting {
            animatePresentation(using: transitionContext)
        } else {
            animateDismissal(using: transitionContext)
        }
    }

    func animatePresentation(using transitionContext: any UIViewControllerContextTransitioning) {
        guard let toVC = transitionContext.viewController(forKey: .to) as? ImagePreviewTransitioning,
              let toView = transitionContext.view(forKey: .to)
        else {
            transitionContext.completeTransition(false)
            return
        }

        let containerView = transitionContext.containerView
        toView.frame = containerView.bounds
        containerView.addSubview(toView)
        toView.layoutIfNeeded()

        toVC.prepareForTransition(isPresenting: isPresenting)

        animator.addAnimations { [isPresenting] in
            toVC.performTransition(isPresenting: isPresenting)
        }

        animator.addCompletion { position in
            if position == .end {
                let didComplete = !transitionContext.transitionWasCancelled
                transitionContext.completeTransition(didComplete)
            }
        }

        animator.startAnimation()
    }

    func animateDismissal(using transitionContext: any UIViewControllerContextTransitioning) {
        guard let fromVC = transitionContext.viewController(forKey: .from) as? ImagePreviewTransitioning else {
            transitionContext.completeTransition(false)
            return
        }
        fromVC.prepareForTransition(isPresenting: isPresenting)
        animator.addAnimations { [isPresenting] in
            fromVC.performTransition(isPresenting: isPresenting)
        }
        animator.addCompletion { position in
            if position == .end {
                let didComplete = !transitionContext.transitionWasCancelled
                transitionContext.completeTransition(didComplete)
            }
        }
        animator.startAnimation()
    }
}
