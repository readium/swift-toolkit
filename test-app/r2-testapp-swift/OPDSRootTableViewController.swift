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
    case MixedGroup
    case MixedNavigationPublication
    case MixedNavigationGroup
    case MixedNavigationGroupPublication
    case None
}

class OPDSRootTableViewController: UITableViewController {
    
    var originalFeedURL: URL?
    var nextPageURL: URL?
    var originalFeedIndexPath: IndexPath?
    var mustEditFeed = false
  
    var parseData: ParseData?
    var feed: Feed?
    var publication: Publication?
    
    var browsingState: FeedBrowsingState = .None
    
    enum GeneralScreenOrientation: String {
        case landscape
        case portrait
    }
    
    static let iPadLayoutHeightForRow:[GeneralScreenOrientation: CGFloat] = [.portrait: 330, .landscape: 340]
    static let iPhoneLayoutHeightForRow:[GeneralScreenOrientation: CGFloat] = [.portrait: 230, .landscape: 280]
    
    lazy var layoutHeightForRow:[UIUserInterfaceIdiom:[GeneralScreenOrientation: CGFloat]] = [
        .pad : OPDSRootTableViewController.iPadLayoutHeightForRow,
        .phone : OPDSRootTableViewController.iPhoneLayoutHeightForRow
    ]
    
    fileprivate var previousScreenOrientation: GeneralScreenOrientation?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        
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
                }.then { newParseData -> Void in
                    self.parseData = newParseData
                }.always {
                    self.finishFeedInitialization()
            }
        }
    }
    
    func finishFeedInitialization() {
        if let feed = parseData?.feed {
            self.feed = feed
            
            navigationItem.title = feed.metadata.title
            self.nextPageURL = self.findNextPageURL(feed: feed)
            
            if feed.facets.count > 0 {
                let filterButton = UIBarButtonItem(title: "Filter",
                                                   style: UIBarButtonItemStyle.plain,
                                                   target: self,
                                                   action: #selector(OPDSRootTableViewController.filterMenuClicked))
                navigationItem.rightBarButtonItem = filterButton
            }
            
            // Check feed compozition. Then, browsingState will be used to build the UI.
            if feed.navigation.count > 0 && feed.groups.count == 0 && feed.publications.count == 0 {
                browsingState = .Navigation
            } else if feed.publications.count > 0 && feed.groups.count == 0 && feed.navigation.count == 0 {
                browsingState = .Publication
                tableView.separatorStyle = .none
                tableView.isScrollEnabled = false
            } else if feed.groups.count > 0 && feed.publications.count == 0 && feed.navigation.count == 0 {
                browsingState = .MixedGroup
            } else if feed.navigation.count > 0 && feed.groups.count == 0 && feed.publications.count > 0 {
                browsingState = .MixedNavigationPublication
            } else if feed.navigation.count > 0 && feed.groups.count > 0 && feed.publications.count == 0 {
                browsingState = .MixedNavigationGroup
            } else if feed.navigation.count > 0 && feed.groups.count > 0 && feed.publications.count > 0 {
                browsingState = .MixedNavigationGroupPublication
            } else {
                browsingState = .None
            }
            
        } else {
            
            tableView.backgroundView = UIView(frame: UIScreen.main.bounds)
            tableView.separatorStyle = .none
            
            let frame = CGRect(x: 0, y: tableView.backgroundView!.bounds.height / 2, width: tableView.backgroundView!.bounds.width, height: 20)
            
            let messageLabel = UILabel(frame: frame)
            messageLabel.textColor = UIColor.darkGray
            messageLabel.textAlignment = .center
            messageLabel.text = "Something goes wrong."
            
            let editButton = UIButton(type: .system)
            editButton.frame = frame
            editButton.setTitle("Edit catalog", for: .normal)
            editButton.addTarget(self, action:#selector(self.editButtonClicked), for: .touchUpInside)
            editButton.isHidden = originalFeedIndexPath == nil ? true : false
            
            let stackView = UIStackView(arrangedSubviews: [messageLabel, editButton])
            stackView.axis = .vertical
            stackView.distribution = .equalSpacing
            let spacing: CGFloat = 15
            stackView.spacing = spacing
            
            tableView.backgroundView?.addSubview(stackView)
            
            stackView.translatesAutoresizingMaskIntoConstraints = false
            stackView.widthAnchor.constraint(equalTo: tableView.backgroundView!.widthAnchor).isActive = true
            stackView.heightAnchor.constraint(equalToConstant: messageLabel.frame.height + editButton.frame.height + spacing).isActive = true
            stackView.centerYAnchor.constraint(equalTo: tableView.backgroundView!.centerYAnchor).isActive = true
            
        }
        
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            self.tableView.reloadData()
        }
    }
    
    @objc func editButtonClicked(_ sender: UIBarButtonItem) {
        mustEditFeed = true
        navigationController?.popViewController(animated: true)
    }
    
    func findNextPageURL(feed: Feed) -> URL? {
        for link in feed.links {
            for rel in link.rel {
                if rel == "next" {
                    return URL(string: link.absoluteHref!)
                }
            }
        }
        return nil
    }
    
    public func loadNextPage(completionHandler: @escaping (Feed?) -> ()) {
        if let nextPageURL = nextPageURL {
            firstly {
                OPDSParser.parseURL(url: nextPageURL)
                }.then { newParseData -> Void in
                    if let newFeed = newParseData.feed {
                        self.nextPageURL = self.findNextPageURL(feed: newFeed)
                        self.feed?.publications.append(contentsOf: newFeed.publications)
                        completionHandler(self.feed)
                    }
                }
        }
    }
    
    //MARK: - Facets
    
    @objc func filterMenuClicked(_ sender: UIBarButtonItem) {

        let opdsStoryboard = UIStoryboard(name: "OPDS", bundle: nil)
        
        if let opdsFacetViewController = opdsStoryboard.instantiateViewController(withIdentifier: "opdsFacetViewController") as? OPDSFacetViewController {
            opdsFacetViewController.modalPresentationStyle = UIModalPresentationStyle.popover
            opdsFacetViewController.feed = feed!
            opdsFacetViewController.rootViewController = self
            
            present(opdsFacetViewController, animated: true, completion: nil)
            
            if let popoverPresentationController = opdsFacetViewController.popoverPresentationController {
                popoverPresentationController.barButtonItem = sender
            }
        }
        
    }

    public func applyFacetAt(indexPath: IndexPath) {
        if let absoluteHref = feed!.facets[indexPath.section].links[indexPath.row].absoluteHref {
            pushOpdsRootViewController(href: absoluteHref)
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        var numberOfSections = 0
        
        switch browsingState {
            
        case .Navigation, .Publication:
            numberOfSections = 1
            
        case .MixedGroup:
            numberOfSections = feed!.groups.count
            
        case .MixedNavigationPublication:
            numberOfSections = 2
            
        case .MixedNavigationGroup:
            // 1 section for the nav + groups count for the next sections
            numberOfSections = 1 + feed!.groups.count
            
        case .MixedNavigationGroupPublication:
            numberOfSections = 1 + feed!.groups.count + 1
            
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
            
        case .MixedGroup:
            if feed!.groups[section].navigation.count > 0 {
                numberOfRowsInSection = feed!.groups[section].navigation.count
            } else {
                numberOfRowsInSection = 1
            }
            
        case .MixedNavigationPublication:
            if section == 0 {
                numberOfRowsInSection = feed!.navigation.count
            }
            if section == 1 {
                numberOfRowsInSection = 1
            }
            
        case .MixedNavigationGroup:
            // Nav
            if section == 0 {
                numberOfRowsInSection = feed!.navigation.count
            }
            // Groups
            if section >= 1 && section <= feed!.groups.count {
                if feed!.groups[section - 1].navigation.count > 0 {
                    // Nav inside a group
                    numberOfRowsInSection = feed!.groups[section - 1].navigation.count
                } else {
                    // No nav inside a group
                    numberOfRowsInSection = 1
                }
            }
            
        case .MixedNavigationGroupPublication:
            if section == 0 {
                numberOfRowsInSection = feed!.navigation.count
            }
            if section >= 1 && section <= feed!.groups.count {
                if feed!.groups[section - 1].navigation.count > 0 {
                    numberOfRowsInSection = feed!.groups[section - 1].navigation.count
                } else {
                    numberOfRowsInSection = 1
                }
            }
            if section == (feed!.groups.count + 1) {
                numberOfRowsInSection = 1
            }
            
        default:
            numberOfRowsInSection = 0
            
        }
        
        return numberOfRowsInSection
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var heightForRowAt: CGFloat = 0.0
        
        switch browsingState {
            
        case .Publication:
            heightForRowAt = tableView.bounds.height
            
        case .MixedGroup:
            if feed!.groups[indexPath.section].navigation.count > 0 {
                heightForRowAt = 44
            } else {
                heightForRowAt = calculateRowHeightForGroup(feed!.groups[indexPath.section ])
            }
            
        case .MixedNavigationPublication:
            if indexPath.section == 0 {
                heightForRowAt = 44
            } else {
                heightForRowAt = tableView.bounds.height / 2
            }
            
        case .MixedNavigationGroup:
            // Nav
            if indexPath.section == 0 {
                heightForRowAt = 44
            // Group
            } else {
                // Nav inside a group
                if feed!.groups[indexPath.section - 1].navigation.count > 0 {
                    heightForRowAt = 44
                } else {
                    // No nav inside a group
                    heightForRowAt = calculateRowHeightForGroup(feed!.groups[indexPath.section - 1])
                }
            }
            
        case .MixedNavigationGroupPublication:
            if indexPath.section == 0 {
                heightForRowAt = 44
            } else if indexPath.section >= 1 && indexPath.section <= feed!.groups.count {
                if feed!.groups[indexPath.section - 1].navigation.count > 0 {
                    heightForRowAt = 44
                } else {
                    heightForRowAt = calculateRowHeightForGroup(feed!.groups[indexPath.section - 1])
                }
            } else {
                let group = Group(title: feed!.metadata.title)
                group.publications = feed!.publications
                heightForRowAt = calculateRowHeightForGroup(group)
            }
            
        default:
            heightForRowAt = 44
            
        }
        
        return heightForRowAt
    }
    
    fileprivate func calculateRowHeightForGroup(_ group: Group) -> CGFloat {
        
        if group.navigation.count > 0 {
            
            return tableView.bounds.height / 2
            
        } else {
            
            let idiom = { () -> UIUserInterfaceIdiom in
                let tempIdion = UIDevice.current.userInterfaceIdiom
                return (tempIdion != .pad) ? .phone:.pad // ignnore carplay and others
            } ()
            
            let orientation = { () -> GeneralScreenOrientation in
                let deviceOrientation = UIDevice.current.orientation
                
                switch deviceOrientation {
                case .unknown, .portrait, .portraitUpsideDown:
                    return GeneralScreenOrientation.portrait
                case .landscapeLeft, .landscapeRight:
                    return GeneralScreenOrientation.landscape
                case .faceUp, .faceDown:
                    return previousScreenOrientation ?? .portrait
                }
            } ()
            
            previousScreenOrientation = orientation
            
            guard let deviceLayoutHeightForRow = layoutHeightForRow[idiom] else {return 44}
            guard let heightForRow = deviceLayoutHeightForRow[orientation] else {return 44}
            
            return heightForRow
            
        }
        
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var title: String?

        switch browsingState {
            
        case .MixedGroup:
            if section >= 0 && section <= feed!.groups.count {
                title = feed!.groups[section].metadata.title
            }
            
        case .MixedNavigationGroup:
            // Nav
            if section == 0 {
                title = "Browse"
            }
            // Groups
            if section >= 1 && section <= feed!.groups.count {
                title = feed!.groups[section-1].metadata.title
            }
            
        case .MixedNavigationGroupPublication:
            if section == 0 {
                title = "Browse"
            }
            if section >= 1 && section <= feed!.groups.count {
                title = feed!.groups[section-1].metadata.title
            }
            if section > feed!.groups.count {
                title = feed!.metadata.title
            }

        default:
            title = nil

        }

        return title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell?
        
        switch browsingState {
            
        case .Navigation:
            cell = buildNavigationCell(tableView: tableView, indexPath: indexPath)
            
        case .Publication:
            cell = buildPublicationCell(tableView: tableView, indexPath: indexPath)
            
        case .MixedGroup:
            cell = buildGroupCell(tableView: tableView, indexPath: indexPath)
            
        case .MixedNavigationPublication:
            if indexPath.section == 0 {
                cell = buildNavigationCell(tableView: tableView, indexPath: indexPath)
            } else {
                cell = buildPublicationCell(tableView: tableView, indexPath: indexPath)
            }
            
        case .MixedNavigationGroup, .MixedNavigationGroupPublication:
            if indexPath.section == 0 {
                // Nav
                cell = buildNavigationCell(tableView: tableView, indexPath: indexPath)
            } else {
                // Groups
                cell = buildGroupCell(tableView: tableView, indexPath: indexPath)
            }

        default:
            cell = nil
            
        }
        
        return cell!
    }
    
    func buildNavigationCell(tableView: UITableView, indexPath: IndexPath) -> OPDSNavigationTableViewCell {
        let castedCell = tableView.dequeueReusableCell(withIdentifier: "opdsNavigationCell", for: indexPath) as! OPDSNavigationTableViewCell
        
        var currentNavigation: [Link]?
        
        if let navigation = feed?.navigation, navigation.count > 0 {
            currentNavigation = navigation
        } else {
            if let navigation = feed?.groups[indexPath.section].navigation, navigation.count > 0 {
                currentNavigation = navigation
            }
        }

        if let currentNavigation = currentNavigation {
            castedCell.title.text = currentNavigation[indexPath.row].title
            if let count = currentNavigation[indexPath.row].properties.numberOfItems {
                castedCell.count.text = "\(count)"
            } else {
                castedCell.count.text = ""
            }
        }
        
        return castedCell
    }
    
    func buildPublicationCell(tableView: UITableView, indexPath: IndexPath) -> OPDSPublicationTableViewCell {
        let castedCell = tableView.dequeueReusableCell(withIdentifier: "opdsPublicationCell", for: indexPath) as! OPDSPublicationTableViewCell
        castedCell.feed = feed
        castedCell.opdsRootTableViewController = self
        return castedCell
    }
    
    func buildGroupCell(tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {

        if browsingState != .MixedGroup {
            if indexPath.section > feed!.groups.count {
                let group = Group(title: feed!.metadata.title)
                group.publications = feed!.publications
                return preparedGroupCell(group: group, indexPath: indexPath, offset: 0)
            } else {
                if feed!.groups[indexPath.section - 1].navigation.count > 0 {
                    return buildNavigationCell(tableView: tableView, indexPath: indexPath)
                } else {
                    return preparedGroupCell(group: nil, indexPath: indexPath, offset: 1)
                }
            }
        } else {
            if feed!.groups[indexPath.section].navigation.count > 0 {
                return buildNavigationCell(tableView: tableView, indexPath: indexPath)
            } else {
                return preparedGroupCell(group: nil, indexPath: indexPath, offset: 0)
            }
        }

    }
    
    fileprivate func preparedGroupCell(group: Group?, indexPath: IndexPath, offset: Int) -> OPDSGroupTableViewCell {
        let castedCell = tableView.dequeueReusableCell(withIdentifier: "opdsGroupCell", for: indexPath) as! OPDSGroupTableViewCell
        castedCell.group = group != nil ? group : feed?.groups[indexPath.section - offset]
        castedCell.opdsRootTableViewController = self
        return castedCell
    }
    
    // MARK: - Table view delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch browsingState {
            
        case .Navigation, .MixedNavigationPublication, .MixedNavigationGroup, .MixedNavigationGroupPublication:
            if indexPath.section == 0 {
                if let absoluteHref = feed!.navigation[indexPath.row].absoluteHref {
                    pushOpdsRootViewController(href: absoluteHref)
                }
            } else if indexPath.section >= 1 && indexPath.section <= feed!.groups.count {
                if feed!.groups[indexPath.section - 1].navigation.count > 0 {
                    if let absoluteHref = feed!.groups[indexPath.section - 1].navigation[indexPath.row].absoluteHref {
                        pushOpdsRootViewController(href: absoluteHref)
                    }
                }
            }

        default:
            break
            
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.boldSystemFont(ofSize: 13)
        
        var offset: Int
        
        if browsingState != .MixedGroup {
            offset = section - 1
        } else {
            offset = section
        }
        
        if let feed = feed {
            
            if let moreButton = view.subviews.last as? OPDSMoreButton {
                if offset >= 0 && offset < feed.groups.count {
                    moreButton.offset = offset
                } else {
                    view.subviews.last?.removeFromSuperview()
                }
                return
            }
            
            if offset >= 0 && offset < feed.groups.count {
                let links = feed.groups[offset].links
                if links.count > 0 {
                    let buttonWidth: CGFloat = 70
                    let moreButton = OPDSMoreButton(type: .system)
                    moreButton.frame = CGRect(x: header.frame.width - buttonWidth, y: 0, width: buttonWidth, height: header.frame.height)
                    
                    moreButton.setTitle("more >", for: .normal)
                    moreButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 11)
                    moreButton.setTitleColor(UIColor.darkGray, for: .normal)
                    
                    moreButton.offset = offset
                    moreButton.addTarget(self, action: #selector(moreAction), for: .touchUpInside)
                    
                    view.addSubview(moreButton)
                    
                    moreButton.translatesAutoresizingMaskIntoConstraints = false
                    moreButton.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
                    moreButton.heightAnchor.constraint(equalToConstant: header.frame.height).isActive = true
                    moreButton.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
                }
            }
            
        }
        
    }
    
    //MARK: - Target action
    
    @objc func moreAction(sender: UIButton!) {
        if let moreButton = sender as? OPDSMoreButton {
            if let href = feed?.groups[moreButton.offset!].links[0].href {
                pushOpdsRootViewController(href: href)
            }
        }
    }

}

//MARK: - UINavigationController delegate and tooling

extension OPDSRootTableViewController: UINavigationControllerDelegate {
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if mustEditFeed {
            (viewController as? OPDSCatalogSelectorViewController)?.mustEditAtIndexPath = originalFeedIndexPath
        }
    }
    
    fileprivate func pushOpdsRootViewController(href: String) {
        let opdsStoryboard = UIStoryboard(name: "OPDS", bundle: nil)
        let opdsRootViewController = opdsStoryboard.instantiateViewController(withIdentifier: "opdsRootViewController") as? OPDSRootTableViewController
        if let opdsRootViewController = opdsRootViewController {
            opdsRootViewController.originalFeedURL = URL(string: href)
            navigationController?.pushViewController(opdsRootViewController, animated: true)
        }
    }
    
}

//MARK: - Sublass of UIButton

class OPDSMoreButton: UIButton {
    var offset: Int?
}
