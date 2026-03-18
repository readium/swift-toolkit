//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import UIKit

/// A navigation controller wrapper for image preview that owns the custom
/// transition and forwards `ImagePreviewTransitioning` to its top view
/// controller.
final class ImagePreviewNavigationController: UINavigationController, ImagePreviewTransitioning {
    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)

        modalPresentationStyle = .fullScreen
        transitioningDelegate = self
        view.backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - ImagePreviewTransitioning

    func prepareForTransition(isPresenting: Bool) {
        (topViewController as? ImagePreviewTransitioning)?
            .prepareForTransition(isPresenting: isPresenting)

        if isPresenting {
            navigationBar.alpha = 0
        }
    }

    func performTransition(isPresenting: Bool) {
        (topViewController as? ImagePreviewTransitioning)?
            .performTransition(isPresenting: isPresenting)

        navigationBar.alpha = isPresenting ? 1 : 0
    }
}

// MARK: - UIViewControllerTransitioningDelegate

extension ImagePreviewNavigationController: UIViewControllerTransitioningDelegate {
    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        ImagePreviewTransition(isPresenting: true)
    }

    func animationController(
        forDismissed dismissed: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        ImagePreviewTransition(isPresenting: false)
    }
}
