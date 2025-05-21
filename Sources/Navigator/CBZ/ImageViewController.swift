//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UIKit

/// Zoomable image view controller.
final class ImageViewController: UIViewController, Loggable {
    /// Index of the resource.
    let index: Int

    /// URL to the image to display.
    private let url: URL

    private var scrollView: UIScrollView!
    private var imageView: UIImageView!

    init(index: Int, url: URL) {
        self.index = index
        self.url = url

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear

        scrollView = UIScrollView(frame: view.bounds)
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.backgroundColor = .clear
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        view.addSubview(scrollView)

        imageView = UIImageView(frame: scrollView.bounds)
        imageView.backgroundColor = .clear
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)

        // Adds an empty view before the scroll view to have a consistent behavior on all iOS
        // versions, regarding to the content inset adjustements. Even if
        // automaticallyAdjustsScrollViewInsets is not set to false on the navigator's parent view
        // controller, the scroll view insets won't be adjusted if the scroll view is not the first
        // child in the subviews hierarchy.
        view.insertSubview(UIView(frame: .zero), at: 0)
        // Prevents the pages from jumping down when the status bar is toggled
        scrollView.contentInsetAdjustmentBehavior = .never

        loadURL()
    }

    private func loadURL() {
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, let image = UIImage(data: data) else {
                if let error = error {
                    self.log(.error, error)
                } else {
                    self.log(.error, "Can't load resource at \(self.url)")
                }
                return
            }

            DispatchQueue.main.async {
                UIView.transition(
                    with: self.imageView,
                    duration: 0.1,
                    options: .transitionCrossDissolve,
                    animations: {
                        self.imageView.image = image
                    }
                )
            }
        }.resume()
    }
}

extension ImageViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }
}
