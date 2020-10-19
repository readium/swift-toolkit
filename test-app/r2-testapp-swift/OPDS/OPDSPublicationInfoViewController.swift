//
//  OPDSPublicationInfoViewController.swift
//  r2-testapp-swift
//
//  Created by Nikita Aizikovskyi on Mar-27-2018.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import R2Shared
import Kingfisher

protocol OPDSPublicationInfoViewControllerFactory {
    func make(publication: Publication) -> OPDSPublicationInfoViewController
}

class OPDSPublicationInfoViewController: UIViewController, Loggable {

    weak var moduleDelegate: OPDSModuleDelegate?
    
    var publication: Publication?

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var fxImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var downloadButton: UIButton!
    @IBOutlet weak var downloadActivityIndicator: UIActivityIndicatorView!
    
    private lazy var downloadLink: Link? = publication?.downloadLinks.first

    override func viewDidLoad() {
        fxImageView.clipsToBounds = true
        fxImageView!.contentMode = .scaleAspectFill
        imageView!.contentMode = .scaleAspectFit
        
        let titleTextView = OPDSPlaceholderPublicationView(
            frame: imageView.frame,
            title: publication?.metadata.title,
            author: publication?.metadata.authors
                .map { $0.name }
                .joined(separator: ", ")
        )
    
        if let images = publication?.images {
            if images.count > 0 {
                let coverURL = URL(string: images[0].href)
                if (coverURL != nil) {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = true
                    imageView.kf.setImage(
                        with: coverURL,
                        placeholder: titleTextView,
                        options: [.transition(ImageTransition.fade(0.5))],
                        progressBlock: nil
                    ) { result in
                        DispatchQueue.main.async {
                            UIApplication.shared.isNetworkActivityIndicatorVisible = false
                        }
                        switch result {
                        case .success(let image):
                            self.fxImageView?.image = image.image
                            UIView.transition(
                                with: self.fxImageView,
                                duration: 0.3,
                                options: .transitionCrossDissolve,
                                animations: { self.fxImageView?.image = image.image },
                                completion: nil
                            )
                        case .failure(_):
                            break
                        }
                    }
                }
            }
        }
        
        titleLabel.text = publication?.metadata.title
        authorLabel.text = publication?.metadata.authors
            .map { $0.name }
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
        
        downloadActivityIndicator.startAnimating()
        downloadButton.isEnabled = false
        delegate.opdsDownloadPublication(publication, at: downloadLink, sender: self) { [weak self] result in
            guard let self = self else {
                return
            }
            
            self.downloadActivityIndicator.stopAnimating()
            self.downloadButton.isEnabled = true
            
            switch result {
            case .success(let book):
                delegate.presentAlert(
                    NSLocalizedString("success_title", comment: "Title of the alert when a publication is successfully downloaded"),
                    message: String(format: NSLocalizedString("library_download_success_message", comment: "Message of the alert when a publication is successfully downloaded"), book.title),
                    from: self
                )
                
            case .failure(let error):
                delegate.presentError(error, from: self)

            case .cancelled:
                break
            }
        }
    }

}
