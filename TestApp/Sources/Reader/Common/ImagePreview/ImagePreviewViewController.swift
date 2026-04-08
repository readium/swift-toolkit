//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumNavigator
import ReadiumShared
import UIKit

/// A simple image preview presented as a sheet.
///
/// Displays the image and basic metadata (href, caption) to demonstrate
/// the Readium `ImageContentElement` API.
final class ImagePreviewViewController: UIViewController {
    private let image: ImageContentElement
    private let publication: Publication
    private let imageView = UIImageView()
    private let linkLabel = UILabel()

    init(image: ImageContentElement, publication: Publication) {
        self.image = image
        self.publication = publication

        super.init(nibName: nil, bundle: nil)

        title = image.caption
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

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        linkLabel.text = image.embeddedLink.href
        linkLabel.textAlignment = .center
        linkLabel.textColor = .secondaryLabel
        linkLabel.numberOfLines = 0
        linkLabel.font = .preferredFont(forTextStyle: .footnote)
        linkLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(linkLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.6),

            linkLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 12),
            linkLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            linkLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])

        Task { @MainActor in
            let link = image.embeddedLink
            if let resource = publication.get(link),
               let imageData = try? await resource.read().get()
            {
                imageView.image = UIImage(data: imageData)
            }
        }
    }
}
