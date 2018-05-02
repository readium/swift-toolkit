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
    @IBOutlet weak var downloadButton: UIButton!
    @IBOutlet weak var downloadActivityIndicator: UIActivityIndicatorView!

    override func viewDidLoad() {
        fxImageView.clipsToBounds = true
        fxImageView!.contentMode = .scaleAspectFill
        imageView!.contentMode = .scaleAspectFit
        
        if let images = publication?.images {
            if images.count > 0 {
                let href = images[0].href!
                let coverURL = URL(string: href)
                if (coverURL != nil) {
                    imageView!.kf.setImage(with: coverURL, placeholder: nil,
                                           options: [.transition(ImageTransition.fade(0.5))],
                                           progressBlock: nil, completionHandler: nil)
                    fxImageView?.image = imageView?.image
                }
            }
        }
        
        titleLabel.text = publication?.metadata.title
        authorLabel.text = publication?.metadata.authors.map({$0.name ?? ""}).joined(separator: ", ")
        
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
            
            let sessionConfiguration = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfiguration)
            let request = URLRequest(url:url)
            
            let task = session.downloadTask(with: request) { (localURL, response, error) in
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
                    DispatchQueue.main.async {
                        // We use the app delegate method that handle the adding of a publication to the
                        // document library
                        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                            let _ = appDelegate.addPublicationToLibrary(url: fixedURL)
                        }
                    }
                } else {
                    // Download failed
                    print("Error while downloading a publication.")
                }
                
                DispatchQueue.main.async {
                    self.downloadActivityIndicator.stopAnimating()
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    self.downloadButton.isEnabled = true
                }
            }
            
            task.resume()
            
        }
        
    }
    
    // Parse publication selected to retrieve links containing a free href
    // and pointing to an epub or lcpl file
    fileprivate func getDownloadURL() -> URL? {
        var url: URL?
        
        if let links = publication?.links {
            for link in links {
                if let href = link.href {
                    if href.contains(".epub") || href.contains(".lcpl") {
                        url = URL(string: href)
                        break
                    }
                }
            }
        }
        
        return url
    }
    
}
