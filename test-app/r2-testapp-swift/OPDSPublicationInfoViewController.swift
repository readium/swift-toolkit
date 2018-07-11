//
//  OPDSPublicationInfoViewController.swift
//  r2-testapp-swift
//
//  Created by Nikita Aizikovskyi on Mar-27-2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import UIKit
import R2Shared
import Kingfisher

class OPDSPublicationInfoViewController : UIViewController {
    var publication: Publication?
    var downloadURL: URL?

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var fxImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var downloadButton: UIButton!
    @IBOutlet weak var downloadActivityIndicator: UIActivityIndicatorView!

    override func viewDidLoad() {
        fxImageView.clipsToBounds = true
        fxImageView!.contentMode = .scaleAspectFill
        imageView!.contentMode = .scaleAspectFit
        
        let titleTextView = OPDSPlaceholderPublicationView(frame: imageView.frame,
                                                           title: publication?.metadata.title,
                                                           author: publication?.metadata.authors.map({$0.name ?? ""}).joined(separator: ", "))
    
        if let images = publication?.images {
            if images.count > 0 {
                let absoluteHref = images[0].absoluteHref!
                let coverURL = URL(string: absoluteHref)
                if (coverURL != nil) {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = true
                    imageView!.kf.setImage(with: coverURL,
                                           placeholder: titleTextView,
                                           options: [.transition(ImageTransition.fade(0.5))],
                                           progressBlock: nil) { (image, _, _, _) in
                                            DispatchQueue.main.async {
                                                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                                            }
                                            self.fxImageView?.image = image
                                            UIView.transition(with: self.fxImageView,
                                                              duration: 0.3,
                                                              options: .transitionCrossDissolve,
                                                              animations: {
                                                                self.fxImageView?.image = image
                                                                
                                            }, completion: nil)
                    }
                }
            }
        }
        
        titleLabel.text = publication?.metadata.title
        authorLabel.text = publication?.metadata.authors.map({$0.name ?? ""}).joined(separator: ", ")
        descriptionLabel.text = publication?.metadata.description
        descriptionLabel.sizeToFit()
        
        downloadActivityIndicator.stopAnimating()
        
        downloadURL = getDownloadURL()
        
        // If we are not able to get a free link, we hide the download button
        // TODO: handle payment or redirection for others links?
        if downloadURL == nil {
            downloadButton.isHidden = true
        }
    }
    
    @IBAction func downloadBook(_ sender: UIButton) {
        
        if let url = downloadURL {
            
            downloadActivityIndicator.startAnimating()
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            downloadButton.isEnabled = false
            
            let request = URLRequest(url:url)
            
            DownloadSession.shared.launch(request: request, completionHandler: { (localURL, response, error, downloadTask) -> Bool in
                
                DispatchQueue.main.async {
                    self.downloadActivityIndicator.stopAnimating()
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    self.downloadButton.isEnabled = true
                }
                
                if let localURL = localURL, error == nil {
                    // Download succeed
                    // downloadTask renames the file download, thus to be parsed correctly according to
                    // the filetype, we first have to rename the downloaded file to its original filename
                    var fixedURL = localURL.deletingLastPathComponent()
                    fixedURL.appendPathComponent(url.lastPathComponent, isDirectory: false)
                    do {
                        try FileManager.default.moveItem(at: localURL, to: fixedURL)
                    } catch {
                        print("\(error)")
                    }
                    
                    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
                        return false
                    }
                    
                    return appDelegate.addPublicationToLibrary(url: fixedURL, needUIUpdate: false)
                    
                } else {
                    // Download failed
                    print("Error while downloading a publication.")
                }
                
                return false
            })
        }
        
    }
    
    // Parse publication selected to retrieve links containing a free href
    // and pointing to an epub or lcpl file
    fileprivate func getDownloadURL() -> URL? {
        var url: URL?
        
        if let links = publication?.links {
            for link in links {
                if let absoluteHref = link.absoluteHref {
                    if absoluteHref.contains(".epub") || absoluteHref.contains(".lcpl") {
                        url = URL(string: absoluteHref)
                        break
                    }
                }
            }
        }
        
        return url
    }
    
}
