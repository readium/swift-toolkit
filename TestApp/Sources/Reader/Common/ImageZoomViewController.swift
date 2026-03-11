//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumNavigator
import ReadiumShared
import UIKit

/// A simple fullscreen image viewer that supports pinch-to-zoom and
/// double-tap to toggle zoom level.
///
/// It animates from the source frame (the image's position in the
/// navigator) and dismisses back to it, giving a smooth Photos-like
/// transition.
final class ImageZoomViewController: UIViewController {
    private let link: Link
    private let sourceFrame: CGRect
    private let publication: Publication
    private let altText: String?
    private let backgroundColor: UIColor

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let backgroundView = UIView()
    private let navigationBar = UINavigationBar()

    init(link: Link, sourceFrame: CGRect, publication: Publication, altText: String? = nil, backgroundColor: UIColor = .black) {
        self.link = link
        self.sourceFrame = sourceFrame
        self.publication = publication
        self.altText = altText
        self.backgroundColor = backgroundColor
        super.init(nibName: nil, bundle: nil)

        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear

        backgroundView.frame = view.bounds
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundView.backgroundColor = backgroundColor
        backgroundView.alpha = 0
        view.addSubview(backgroundView)

        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.clipsToBounds = true
        scrollView.addSubview(imageView)

        setupNavigationBar()

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
        scrollView.addGestureRecognizer(singleTap)

        loadImage()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }

    // MARK: - Navigation bar

    private func setupNavigationBar() {
        let foregroundColor = backgroundColor.contrastingColor

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = backgroundColor.withAlphaComponent(0.5)
        appearance.titleTextAttributes = [.foregroundColor: foregroundColor]

        let navItem = UINavigationItem(title: altText ?? "")
        navItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )
        navItem.rightBarButtonItem?.tintColor = foregroundColor
        navigationBar.setItems([navItem], animated: false)
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navigationBar)

        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        navigationBar.alpha = 0
    }

    @objc private func doneTapped() {
        animateDismiss()
    }

    // MARK: - Image loading

    private func loadImage() {
        Task {
            if let data = try? await loadImageData() {
                imageView.image = UIImage(data: data)
            } else {
                // Fallback: try loading directly from URL
                //imageView.image = UIImage(contentsOfFile: imageURL.path)
            }
        }
    }

    private func loadImageData() async throws -> Data {
        guard let resource = publication.get(link) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try await resource.read().get()
    }

    // MARK: - Animations

    private func animateIn() {
        // Start the image view at the source frame.
        imageView.frame = sourceFrame

        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: .curveEaseInOut
        ) {
            self.backgroundView.alpha = 1
            self.navigationBar.alpha = 1
            self.imageView.frame = self.targetFrame()
        }
    }

    private func animateDismiss() {
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.3,
            options: .curveEaseInOut,
            animations: {
                self.backgroundView.alpha = 0
                self.navigationBar.alpha = 0
                self.scrollView.zoomScale = 1.0
                self.imageView.frame = self.sourceFrame
            }
        ) { _ in
            self.dismiss(animated: false)
        }
    }

    private func targetFrame() -> CGRect {
        guard let image = imageView.image else {
            return view.bounds
        }

        let imageSize = image.size
        let viewSize = view.bounds.size

        let widthRatio = viewSize.width / imageSize.width
        let heightRatio = viewSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)

        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale

        return CGRect(
            x: (viewSize.width - scaledWidth) / 2,
            y: (viewSize.height - scaledHeight) / 2,
            width: scaledWidth,
            height: scaledHeight
        )
    }

    // MARK: - Gestures

    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        animateDismiss()
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let zoomRect = CGRect(
                x: point.x - 50,
                y: point.y - 50,
                width: 100,
                height: 100
            )
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }
}

extension ImageZoomViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // Center the image view within the scroll view.
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        imageView.center = CGPoint(
            x: scrollView.contentSize.width / 2 + offsetX,
            y: scrollView.contentSize.height / 2 + offsetY
        )
    }
}

private extension UIColor {
    /// Returns white or black depending on the perceived luminance of this
    /// color, ensuring readable contrast.
    var contrastingColor: UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        // W3C relative luminance formula
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.5 ? .black : .white
    }
}
