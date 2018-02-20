//
//  OPDSLibraryViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 10/30/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import UIKit
import R2Shared
import ReadiumOPDS

class OPDSCatalogViewController: UIViewController {
    var feed: Feed
    var opdsNavigationViewController: OPDSNavigationViewController?
    var publicationViewController: OPDSPublicationsViewController?
    
    init?(feed: Feed) {
        self.feed = feed
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let flowFrame = CGRect(x: 0, y: 44, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height-44)
        view = UIView(frame: flowFrame)
        navigationItem.title = feed.metadata.title
        initSubviews()
    }

    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: false)
        view.frame = view.bounds
        super.viewWillAppear(animated)
    }

    func initSubviews() {
        if feed.navigation.count != 0 {
            opdsNavigationViewController = OPDSNavigationViewController(feed: feed)
            view.addSubview((opdsNavigationViewController?.view)!)
        }
        if feed.publications.count != 0 {
            publicationViewController = OPDSPublicationsViewController(feed.publications, frame: view.frame)
            view.addSubview((publicationViewController?.view)!)
        }
    }
}
