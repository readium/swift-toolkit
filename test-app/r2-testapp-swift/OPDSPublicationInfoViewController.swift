//
//  OPDSPublicationInfoViewController.swift
//  r2-testapp-swift
//
//  Created by Nikita Aizikovskyi on Mar-27-2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import UIKit
import WebKit
import R2Shared
import R2Streamer
import R2Navigator
//import ReadiumLCP
import Kingfisher
import PromiseKit
import ReadiumOPDS


//class OPDSPublicationInfoViewController: UIViewController {
//    var publication: Publication
//    var catalogViewController: OPDSCatalogViewController
//    var imageView: UIImageView?
//
//    init?(_ publication: Publication, catalogViewController: OPDSCatalogViewController) {
//        self.publication = publication
//        self.catalogViewController = catalogViewController
//        super.init(nibName: nil, bundle: nil)
//    }
//
//    @available(*, unavailable)
//    required init?(coder aDecoder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//
//    override func loadView() {
//        view = UIView(frame: UIScreen.main.bounds)
//        view.autoresizesSubviews = true
//
//        let imageFrame = CGRect(x: 10, y: 10, width: 200, height: 200)
//        imageView = UIImageView(frame: imageFrame)
//        view.addSubview(imageView!)
//        let coverUrl = URL(string: publication.images[0].href!)
//        if (coverUrl != nil) {
//        imageView!.kf.setImage(with: coverUrl, placeholder: nil,
//                              options: [.transition(ImageTransition.fade(0.5))],
//                              progressBlock: nil, completionHandler: nil)
//        }
//    }
//
//
//}

import UIKit

class OPDSPublicationInfoViewController : UIViewController {
    var publication: Publication
    var catalogViewController: OPDSCatalogViewController

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var fxImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init?(_ publication: Publication, catalogViewController: OPDSCatalogViewController) {
        self.publication = publication
        self.catalogViewController = catalogViewController
        super.init(nibName: "OPDSPublicationInfoView", bundle: nil)
    }

    override func viewDidLoad() {
        fxImageView.clipsToBounds = true
        fxImageView!.contentMode = .scaleAspectFill
        imageView!.contentMode = .scaleAspectFit
        let coverUrl = URL(string: publication.images[0].href!)
        if (coverUrl != nil) {
            imageView!.kf.setImage(with: coverUrl, placeholder: nil,
                              options: [.transition(ImageTransition.fade(0.5))],
                              progressBlock: nil, completionHandler: nil)
            fxImageView?.image = imageView?.image
        }
        titleLabel.text = publication.metadata.title
        authorLabel.text = publication.metadata.authors.map({$0.name ?? ""}).joined(separator: ", ")
    }
}


