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
    private let bgColor: UIColor

    private let scrollView: UIScrollView
    private let imageView: UIImageView

    init(link: Link,
         publication: Publication,
         altText: String? = nil,
         sourceFrame: CGRect,
         backgroundColor: UIColor = .black)
    {
        self.link = link
        self.sourceFrame = sourceFrame
        self.publication = publication
        bgColor = backgroundColor
        scrollView = UIScrollView()
        imageView = UIImageView()

        super.init(nibName: nil, bundle: nil)

        title = altText
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            }
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()

        view.backgroundColor = bgColor

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
            imageView.frame = sourceFrame
            view.backgroundColor = .clear
        } else {
            scrollView.zoomScale = scrollView.minimumZoomScale
            scrollView.contentInset = .zero
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
        imageView.frame = isPresenting ? targetFrame : sourceFrame
        view.backgroundColor = isPresenting ? bgColor : .clear
    }
}

// MARK: - UIScrollViewDelegate

extension ImagePreviewViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }
}
