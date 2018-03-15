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
import PromiseKit

class OPDSCatalogViewController: UIViewController {
    var feed: Feed?
    var isFeedInitialized: Bool
    var originalFeedURL: URL
    var currentFeedURL: URL
    var nextPageURL: URL?
    public var isLoadingNextPage: Bool
    var opdsNavigationViewController: OPDSNavigationViewController?
    var publicationViewController: OPDSPublicationsViewController?
    var filterButton: UIBarButtonItem?
    var spinnerView: UIActivityIndicatorView?

    init?(url: URL) {
        self.originalFeedURL = url
        self.currentFeedURL = url
        self.isFeedInitialized = false
        self.isLoadingNextPage = false
        super.init(nibName: "OPDSCatalogView", bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let flowFrame = CGRect(x: 0, y: 44, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height-44)
        view = UIView(frame: flowFrame)
        navigationItem.title = ""
        spinnerView = UIActivityIndicatorView.init(activityIndicatorStyle: .whiteLarge)
        spinnerView?.startAnimating()
        spinnerView?.center = view.center
        view.addSubview(spinnerView!)
        parseFeed()
    }

    func parseFeed() {
        firstly {
            OPDSParser.parseURL(url: self.originalFeedURL)
        }.then { newFeed -> Void in
            self.feed = newFeed
            self.finishFeedInitialization()
        }
    }

    func finishFeedInitialization() {
        DispatchQueue.main.async {
            self.spinnerView?.removeFromSuperview()
        }
        self.isFeedInitialized = true
        navigationItem.title = feed!.metadata.title
        self.nextPageURL = self.findNextPageURL(feed: feed!)
        filterButton = UIBarButtonItem(title: "Filter", style: UIBarButtonItemStyle.plain, target: self, action: #selector(OPDSCatalogViewController.filterMenuClicked))
        navigationItem.rightBarButtonItem = filterButton
        initSubviews()
    }

    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: false)
        view.frame = view.bounds
        super.viewWillAppear(animated)
    }

    func loadNewURL(newURL: URL) {
        let opdsCatalog = OPDSCatalogViewController(url: newURL)
        self.navigationController?.pushViewController(opdsCatalog!, animated: true)
    }

    func changeFeed(newFeed: Feed) {
        feed = newFeed
        opdsNavigationViewController?.changeFeed(newFeed: newFeed)
        publicationViewController?.changePublications(newPublications: newFeed.publications)
    }

    func filterMenuClicked(_ sender: UIBarButtonItem) {
        if (!isFeedInitialized) {
            return
        }
        let tableViewController = OPDSFacetTableViewController(feed: feed!, catalogViewController: self)
        tableViewController.modalPresentationStyle = UIModalPresentationStyle.popover

        present(tableViewController, animated: true, completion: nil)


        if let popoverPresentationController = tableViewController.popoverPresentationController {
            popoverPresentationController.barButtonItem = sender
        }
    }

    func initSubviews() {
        if (!isFeedInitialized) {
            return
        }
        if feed!.navigation.count != 0 {
            opdsNavigationViewController = OPDSNavigationViewController(feed: feed!)
            view.addSubview((opdsNavigationViewController?.view)!)
        }
        if feed!.publications.count != 0 {
            publicationViewController = OPDSPublicationsViewController(feed!.publications, frame: view.frame, catalogViewController: self)
            view.addSubview((publicationViewController?.view)!)
        }
    }

    public func getValueForFacet(facet: Int) -> Int? {
        // TODO: remove this function
        return nil
    }

    public func setValueForFacet(facet: Int, value: Int?) {
        if (!isFeedInitialized) {
            return
        }
        if let facetValue = value,
            let hrefValue = self.feed!.facets[facet].links[facetValue].href {
            // hrefValue is only a path, it doesn't have a scheme or domain name.
            // We get those from the original url
            let newURLString = (self.originalFeedURL.scheme ?? "http") + "://" + self.originalFeedURL.host! + hrefValue
            self.loadNewURL(newURL: URL(string: newURLString)!)
        }
        else {
            self.loadNewURL(newURL: self.originalFeedURL) // Note: this fails for multiple facet groups. Figure out a fix when an example is available
        }
    }

    public func findNextPageURL(feed: Feed) -> URL? {
        for link in feed.links {
            for rel in link.rel {
                if rel == "next" {
                    return URL(string: link.href!)
                }
            }
        }
        return nil
    }

    public func loadNextPage() {
        if !self.isFeedInitialized || self.isLoadingNextPage || nextPageURL == nil {
            return
        }
        self.isLoadingNextPage = true
        firstly {
            OPDSParser.parseURL(url: nextPageURL!)
        }.then { newFeed -> Void in
            self.nextPageURL = self.findNextPageURL(feed: newFeed)
            self.feed!.publications.append(contentsOf: newFeed.publications)
            self.changeFeed(newFeed: self.feed!) // changing to the ORIGINAL feed, now with more publications
        }.always {
            self.isLoadingNextPage = false
        }
    }
}
