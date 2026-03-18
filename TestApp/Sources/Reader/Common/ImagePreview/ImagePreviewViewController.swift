//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumNavigator
import ReadiumShared
import UIKit

/// A simple fullscreen image viewer that supports pinch-to-zoom.
///
/// Uses a custom `UIViewControllerAnimatedTransitioning`-based
/// transition that animates the image from its source frame in the
/// navigator to a centered, aspect-fitted position — and back on
/// dismiss — giving a smooth Photos-like experience.
final class ImagePreviewViewController: UIViewController {
    private let link: Link
    private let sourceFrame: CGRect
    private let publication: Publication
    private let altText: String?
    private let backgroundColor: UIColor

    private let scrollView: UIScrollView
    private let imageView: UIImageView
    private let titleLabel: UILabel
    private let closeButton: UIButton

    init(link: Link,
         publication: Publication,
         altText: String? = nil,
         sourceFrame: CGRect,
         backgroundColor: UIColor = .black)
    {
        self.link = link
        self.sourceFrame = sourceFrame
        self.publication = publication
        self.altText = altText
        self.backgroundColor = backgroundColor
        self.scrollView = UIScrollView()
        self.imageView = UIImageView()
        self.titleLabel = UILabel()
        var buttonConfiguration: UIButton.Configuration = {
            if #available(iOS 26.0, *) {
                UIButton.Configuration.prominentGlass()
            } else {
                UIButton.Configuration.borderedProminent()
            }
        }()
        buttonConfiguration.image = UIImage(systemName: "checkmark")
        self.closeButton = UIButton(configuration: buttonConfiguration)

        super.init(nibName: nil, bundle: nil)

        self.modalPresentationStyle = .custom
        self.transitioningDelegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()

        view.backgroundColor = .clear

        scrollView.frame = view.bounds
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        scrollView.addSubview(imageView)

        titleLabel.text = altText
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = backgroundColor.contrastingColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        closeButton.tintColor = backgroundColor.contrastingColor
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        }, for: .primaryActionTriggered)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 12
            ),
            titleLabel.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            closeButton.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 8
            ),
            closeButton.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -16
            )
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        Task { @MainActor in
            if let resource = publication.get(link),
               let imageData = try? await resource.read().get()
            {
                imageView.image = UIImage(data: imageData)
            }
        }
    }
}

// MARK: - ImagePreviewTransitioning

extension ImagePreviewViewController: ImagePreviewTransitioning {

    func prepareForTransition(isPresenting: Bool) {
        if isPresenting {
            self.titleLabel.alpha = 0
            self.closeButton.alpha = 0
            self.imageView.frame = sourceFrame
            self.view.backgroundColor = .clear
        }
    }

    func performTransition(isPresenting: Bool) {
        let targetFrame: CGRect = {
            var frame = view.bounds
            guard let image = imageView.image else {
                return frame
            }
            let aspectRatio = image.size.height / image.size.width
            let width = view.bounds.width
            let height = width * aspectRatio
            frame.size = CGSize(width: width, height: height)
            frame.origin = CGPoint(x: 0, y: (view.bounds.height - height) / 2)
            return frame
        }()
        self.titleLabel.alpha = isPresenting ? 1 : 0
        self.closeButton.alpha = isPresenting ? 1 : 0
        self.imageView.frame = isPresenting ? targetFrame: sourceFrame
        self.view.backgroundColor = isPresenting ? backgroundColor: .clear
    }
}

// MARK: - UIScrollViewDelegate

extension ImagePreviewViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let boundsSize = scrollView.bounds.size
        let contentSize = scrollView.contentSize
        let x = max((boundsSize.width - contentSize.width) / 2, 0)
        let y = max((boundsSize.height - contentSize.height) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
    }
}

// MARK: - UIViewControllerTransitioningDelegate

extension ImagePreviewViewController: UIViewControllerTransitioningDelegate {
    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        ImagePreviewAnimator(isPresenting: true)
    }

    func animationController(
        forDismissed dismissed: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        ImagePreviewAnimator(isPresenting: false)
    }
}

// MARK: - UIColor Extension

private extension UIColor {
    var contrastingColor: UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.5 ? .black : .white
    }
}
