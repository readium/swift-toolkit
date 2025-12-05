//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Kingfisher
import ReadiumShared
import UIKit

protocol OPDSPublicationInfoViewControllerFactory {
    func make(publication: Publication) -> OPDSPublicationInfoViewController
}

class OPDSPublicationInfoViewController: UIViewController, Loggable {
    weak var moduleDelegate: OPDSModuleDelegate?

    var publication: Publication?

    @IBOutlet var imageView: UIImageView!
    @IBOutlet var fxImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var authorLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var downloadButton: UIButton!
    @IBOutlet var downloadActivityIndicator: UIActivityIndicatorView!

    private lazy var downloadLink: Link? = publication?.downloadLinks.first
    private var subscriptions = Set<AnyCancellable>()

    override func viewDidLoad() {
        fxImageView.clipsToBounds = true
        fxImageView!.contentMode = .scaleAspectFill
        imageView!.contentMode = .scaleAspectFit

        let titleTextView = OPDSPlaceholderPublicationView(
            frame: imageView.frame,
            title: publication?.metadata.title,
            author: publication?.metadata.authors
                .map(\.name)
                .joined(separator: ", ")
        )

        if let images = publication?.images {
            if images.count > 0 {
                let coverURL = URL(string: images[0].href)
                if coverURL != nil {
                    imageView.kf.setImage(
                        with: coverURL,
                        placeholder: titleTextView,
                        options: [.transition(ImageTransition.fade(0.5))],
                        progressBlock: nil
                    ) { result in
                        switch result {
                        case let .success(image):
                            self.fxImageView?.image = image.image
                            UIView.transition(
                                with: self.fxImageView,
                                duration: 0.3,
                                options: .transitionCrossDissolve,
                                animations: { self.fxImageView?.image = image.image },
                                completion: nil
                            )
                        case .failure:
                            break
                        }
                    }
                }
            }
        }

        titleLabel.text = publication?.metadata.title
        authorLabel.text = publication?.metadata.authors
            .map(\.name)
            .joined(separator: ", ")
        descriptionLabel.text = publication?.metadata.description
        descriptionLabel.sizeToFit()

        downloadActivityIndicator.stopAnimating()

        // If we are not able to get a free link, we hide the download button
        // TODO: handle payment or redirection for others links?
        if downloadLink == nil {
            downloadButton.isHidden = true
        }
    }

    @IBAction func downloadBook(_ sender: UIButton) {
        guard let delegate = moduleDelegate, let downloadLink = downloadLink else {
            return
        }

        Task {
            downloadActivityIndicator.startAnimating()
            downloadButton.isEnabled = false

            do {
                let book = try await delegate.opdsDownloadPublication(publication, at: downloadLink, sender: self, progress: { _ in })
                delegate.presentAlert(
                    NSLocalizedString("success_title", comment: "Title of the alert when a publication is successfully downloaded"),
                    message: String(format: NSLocalizedString("library_download_success_message", comment: "Message of the alert when a publication is successfully downloaded"), book.title),
                    from: self
                )
            } catch {
                delegate.presentError(UserError(error), from: self)
            }

            downloadActivityIndicator.stopAnimating()
            downloadButton.isEnabled = true
        }
    }
}
