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
   // @IBOutlet weak var mainView: UIView?
  //  @IBOutlet weak var filterButton: UIButton?
    var filterButton: UIBarButtonItem?
    var facetValues: [Int: Int]

    init?(feed: Feed) {
        self.feed = feed
        self.facetValues = [Int: Int]()
        super.init(nibName: "OPDSCatalogView", bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let flowFrame = CGRect(x: 0, y: 44, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height-44)
        view = UIView(frame: flowFrame)
        //super.loadView()
        navigationItem.leftItemsSupplementBackButton = true
        navigationItem.title = feed.metadata.title
        filterButton = UIBarButtonItem(title: "Filter", style: UIBarButtonItemStyle.plain, target: self, action: #selector(OPDSCatalogViewController.filterMenuClicked))
        navigationItem.leftBarButtonItem = filterButton
        initSubviews()
    }

    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: false)
        view.frame = view.bounds
        super.viewWillAppear(animated)
    }

    func filterMenuClicked(_ sender: UIBarButtonItem) {
        let tableViewController = OPDSFacetTableViewController(feed: feed, catalogViewController: self)
        tableViewController.modalPresentationStyle = UIModalPresentationStyle.popover

        present(tableViewController, animated: true, completion: nil)

        let popoverPresentationController = tableViewController.popoverPresentationController
        popoverPresentationController?.barButtonItem = sender
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

    public func getValueForFacet(facet: Int) -> Int? {
        if facetValues.keys.contains(facet) {
            return facetValues[facet]
        }
        return nil
    }

    public func setValueForFacet(facet: Int, value: Int?) {
        facetValues[facet] = value
        // TODO: Actually update the catalog
    }
}
