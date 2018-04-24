//
//  OPDSRootTableViewController.swift
//  r2-testapp-swift
//
//  Created by Geoffrey Bugniot on 23/04/2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import UIKit
import R2Shared
import ReadiumOPDS
import PromiseKit

enum FeedBrowsingState {
    case Navigation
    case Publication
    case Mixed
    case None
}

class OPDSRootTableViewController: UITableViewController {
    
    var originalFeedURL: URL?
    var currentFeedURL: URL?
    var nextPageURL: URL?
    
    var feed: Feed?
    
    var browsingState: FeedBrowsingState = .None

    override func viewDidLoad() {
        super.viewDidLoad()
        parseFeed()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        tableView.reloadData()
    }
    
    // MARK: - OPDS feed parsing
    
    func parseFeed() {
        if let url = originalFeedURL {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            firstly {
                OPDSParser.parseURL(url: url)
                }.then { newFeed -> Void in
                    self.feed = newFeed
                    self.finishFeedInitialization()
            }
        }
    }
    
    func finishFeedInitialization() {
        if let feed = feed {
            navigationItem.title = feed.metadata.title
            self.nextPageURL = self.findNextPageURL(feed: feed)
            
            if feed.facets.count > 0 {
                let filterButton = UIBarButtonItem(title: "Filter",
                                                   style: UIBarButtonItemStyle.plain,
                                                   target: self,
                                                   action: #selector(OPDSRootTableViewController.filterMenuClicked))
                navigationItem.rightBarButtonItem = filterButton
            }
            
            if feed.navigation.count > 0 && feed.groups.count == 0 && feed.publications.count == 0 {
                browsingState = .Navigation
            } else if feed.publications.count > 0 && feed.groups.count == 0 && feed.navigation.count == 0 {
                browsingState = .Publication
                tableView.separatorStyle = .none
                tableView.isScrollEnabled = false
            } else {
                browsingState = .Mixed
            }
            
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
            
            tableView.reloadData()
        }
    }
    
    func findNextPageURL(feed: Feed) -> URL? {
        for link in feed.links {
            for rel in link.rel {
                if rel == "next" {
                    return URL(string: link.href!)
                }
            }
        }
        return nil
    }
    
    public func loadNextPage(completionHandler: @escaping (Feed?) -> ()) {
//        if !self.isFeedInitialized || self.isLoadingNextPage || nextPageURL == nil {
//            return
//        }
//        self.isLoadingNextPage = true
        
        if let nextPageURL = nextPageURL {
            firstly {
                OPDSParser.parseURL(url: nextPageURL)
                }.then { newFeed -> Void in
                    self.nextPageURL = self.findNextPageURL(feed: newFeed)
                    self.feed?.publications.append(contentsOf: newFeed.publications)
                    //self.changeFeed(newFeed: self.feed!) // changing to the ORIGINAL feed, now with more publications
                    //self.feed = newFeed
                    completionHandler(self.feed)
                }.always {
                    //self.isLoadingNextPage = false
            }
        }
        
    }
    
    //MARK: - Facets
    
    func filterMenuClicked(_ sender: UIBarButtonItem) {
//        if (!isFeedInitialized) {
//            return
//        }
        let tableViewController = OPDSFacetTableViewController(feed: feed!, rootViewController: self)
        tableViewController.modalPresentationStyle = UIModalPresentationStyle.popover

        present(tableViewController, animated: true, completion: nil)


        if let popoverPresentationController = tableViewController.popoverPresentationController {
            popoverPresentationController.barButtonItem = sender
        }
    }
    
    public func getValueForFacet(facet: Int) -> Int? {
        // TODO: remove this function
        return nil
    }
    
    public func setValueForFacet(facet: Int, value: Int?) {
//        if (!isFeedInitialized) {
//            return
//        }
        if let facetValue = value, let hrefValue = self.feed!.facets[facet].links[facetValue].href {
            // hrefValue is only a path, it doesn't have a scheme or domain name.
            // We get those from the original url
            let scheme = originalFeedURL?.scheme ?? "http"
            let host = originalFeedURL?.host ?? "unknown"
            let newURLString = scheme + "://" + host + hrefValue
            if let newURL = URL(string: newURLString) {
                loadNewURL(url: newURL)
            }
        }
        else {
            if let originalURL = originalFeedURL {
                loadNewURL(url: originalURL) // Note: this fails for multiple facet groups. Figure out a fix when an example is available
            }
        }
    }
    
    func loadNewURL(url: URL) {
        let opdsStoryboard = UIStoryboard(name: "OPDS", bundle: nil)
        let opdsRootViewController = opdsStoryboard.instantiateViewController(withIdentifier: "opdsRootViewController") as? OPDSRootTableViewController
        if let opdsRootViewController = opdsRootViewController {
            opdsRootViewController.originalFeedURL = url
            navigationController?.pushViewController(opdsRootViewController, animated: true)
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        var numberOfSections = 0
        
        switch browsingState {
            
        case .Navigation, .Publication:
            numberOfSections = 1
            
        case .Mixed:
            numberOfSections = 0
            
        default:
            numberOfSections = 0
            
        }
        
        return numberOfSections
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var numberOfRowsInSection = 0
        
        switch browsingState {
            
        case .Navigation:
            numberOfRowsInSection = feed!.navigation.count
            
        case .Publication:
            numberOfRowsInSection = 1
            
        case .Mixed:
            numberOfRowsInSection = 0
            
        default:
            numberOfRowsInSection = 0
            
        }
        
        return numberOfRowsInSection
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var heightForRowAt: CGFloat = 0.0
        
        switch browsingState {
            
        case .Navigation:
            heightForRowAt = 44
            
        case .Publication:
            heightForRowAt = tableView.bounds.height
            
        case .Mixed:
            heightForRowAt = 44
            
        default:
            heightForRowAt = 44
            
        }
        
        return heightForRowAt
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell?
        
        switch browsingState {
            
        case .Navigation:
            let castedCell = tableView.dequeueReusableCell(withIdentifier: "opdsNavigationCell", for: indexPath) as! OPDSNavigationTableViewCell
            castedCell.title.text = feed?.navigation[indexPath.row].title
            if let count = feed?.navigation[indexPath.row].properties.numberOfItems {
                castedCell.count.text = "\(count)"
            } else {
                castedCell.count.text = ""
            }
            cell = castedCell
            
        case .Publication:
            let castedCell = tableView.dequeueReusableCell(withIdentifier: "opdsPublicationCell", for: indexPath) as! OPDSPublicationTableViewCell
            castedCell.feed = feed
            castedCell.opdsRootTableViewController = self
            cell = castedCell
            
        case .Mixed:
            cell = nil
            
        default:
            cell = nil
            
        }
        
        return cell!
    }
    
    // MARK: - Table view delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch browsingState {
            
        case .Navigation:
            if let href = feed?.navigation[indexPath.row].href {
                let opdsStoryboard = UIStoryboard(name: "OPDS", bundle: nil)
                let opdsRootViewController = opdsStoryboard.instantiateViewController(withIdentifier: "opdsRootViewController") as? OPDSRootTableViewController
                if let opdsRootViewController = opdsRootViewController {
                    opdsRootViewController.originalFeedURL = URL(string: href)
                    navigationController?.pushViewController(opdsRootViewController, animated: true)
                }
            }
            
        case .Publication:
            break
            
        case .Mixed:
            break
            
        default:
            break
            
        }
    }

}
