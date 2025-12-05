//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumOPDS
import ReadiumShared
import SwiftUI
import UIKit

enum FeedBrowsingState {
    case Navigation
    case Publication
    case MixedGroup
    case MixedNavigationPublication
    case MixedNavigationGroup
    case MixedNavigationGroupPublication
    case None
}

protocol OPDSRootTableViewControllerFactory {
    func make(feedURL: URL, indexPath: IndexPath?) -> OPDSRootTableViewController
}

class OPDSRootTableViewController: UITableViewController {
    typealias Factory =
        OPDSRootTableViewControllerFactory

    var factory: Factory!
    var originalFeedURL: URL?

    var nextPageURL: URL?
    var originalFeedIndexPath: IndexPath?
    var mustEditFeed = false

    var parseData: ParseData?
    var feed: Feed?
    var publication: Publication?

    var browsingState: FeedBrowsingState = .None

    static let iPadLayoutHeightForRow: [ScreenOrientation: CGFloat] = [.portrait: 330, .landscape: 340]
    static let iPhoneLayoutHeightForRow: [ScreenOrientation: CGFloat] = [.portrait: 230, .landscape: 280]

    lazy var layoutHeightForRow: [UIUserInterfaceIdiom: [ScreenOrientation: CGFloat]] = [
        .pad: OPDSRootTableViewController.iPadLayoutHeightForRow,
        .phone: OPDSRootTableViewController.iPhoneLayoutHeightForRow,
    ]

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
            OPDSParser.parseURL(url: url) { data, _ in
                DispatchQueue.main.async {
                    if let data = data {
                        self.parseData = data
                    }
                    self.finishFeedInitialization()
                }
            }
        }
    }

    func finishFeedInitialization() {
        if let feed = parseData?.feed {
            self.feed = feed

            navigationItem.title = feed.metadata.title
            nextPageURL = findNextPageURL(feed: feed)

            if feed.facets.count > 0 {
                let filterButton = UIBarButtonItem(
                    title: NSLocalizedString("filter_button", comment: "Filter the OPDS feed"),
                    style: UIBarButtonItem.Style.plain,
                    target: self,
                    action: #selector(OPDSRootTableViewController.filterMenuClicked)
                )
                navigationItem.rightBarButtonItem = filterButton
            }

            // Check feed compozition. Then, browsingState will be used to build the UI.
            if feed.navigation.count > 0, feed.groups.count == 0, feed.publications.count == 0 {
                browsingState = .Navigation
            } else if feed.publications.count > 0, feed.groups.count == 0, feed.navigation.count == 0 {
                browsingState = .Publication
                tableView.separatorStyle = .none
                tableView.isScrollEnabled = false
            } else if feed.groups.count > 0, feed.publications.count == 0, feed.navigation.count == 0 {
                browsingState = .MixedGroup
            } else if feed.navigation.count > 0, feed.groups.count == 0, feed.publications.count > 0 {
                browsingState = .MixedNavigationPublication
            } else if feed.navigation.count > 0, feed.groups.count > 0, feed.publications.count == 0 {
                browsingState = .MixedNavigationGroup
            } else if feed.navigation.count > 0, feed.groups.count > 0, feed.publications.count > 0 {
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
            messageLabel.text = NSLocalizedString("opds_failure_message", comment: "Error message when the feed couldn't be loaded")

            let editButton = UIButton(type: .system)
            editButton.frame = frame
            editButton.setTitle(NSLocalizedString("opds_edit_button", comment: "Button to edit the OPDS catalog"), for: .normal)
            editButton.addTarget(self, action: #selector(editButtonClicked), for: .touchUpInside)
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
            self.tableView.reloadData()
        }
    }

    @objc func editButtonClicked(_ sender: UIBarButtonItem) {
        mustEditFeed = true
        navigationController?.popViewController(animated: true)
    }

    func findNextPageURL(feed: Feed) -> URL? {
        guard let href = feed.links.firstWithRel(.next)?.href else {
            return nil
        }
        return URL(string: href)
    }

    public func loadNextPage(completionHandler: @escaping (Feed?) -> Void) {
        if let nextPageURL = nextPageURL {
            OPDSParser.parseURL(url: nextPageURL) { data, _ in
                DispatchQueue.main.async {
                    guard let newFeed = data?.feed else {
                        return
                    }

                    self.nextPageURL = self.findNextPageURL(feed: newFeed)
                    self.feed?.publications.append(contentsOf: newFeed.publications)
                    completionHandler(self.feed)
                }
            }
        }
    }

    // MARK: - Facets

    @objc func filterMenuClicked(_ sender: UIBarButtonItem) {
        guard let feed = feed else {
            return
        }

        let facetViewController = UIHostingController(rootView: OPDSFacetList(
            feed: feed,
            onLinkSelected: { [weak self] link in
                self?.pushOpdsRootViewController(href: link.href)
            }
        ))

        facetViewController.modalPresentationStyle = UIModalPresentationStyle.popover

        present(facetViewController, animated: true, completion: nil)

        if let popoverPresentationController = facetViewController.popoverPresentationController {
            popoverPresentationController.barButtonItem = sender
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
            if section >= 1, section <= feed!.groups.count {
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
            if section >= 1, section <= feed!.groups.count {
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
                heightForRowAt = calculateRowHeightForGroup(feed!.groups[indexPath.section])
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
            } else if indexPath.section >= 1, indexPath.section <= feed!.groups.count {
                if feed!.groups[indexPath.section - 1].navigation.count > 0 {
                    heightForRowAt = 44
                } else {
                    heightForRowAt = calculateRowHeightForGroup(feed!.groups[indexPath.section - 1])
                }
            } else {
                let group = ReadiumShared.Group(title: feed!.metadata.title)
                group.publications = feed!.publications
                heightForRowAt = calculateRowHeightForGroup(group)
            }

        default:
            heightForRowAt = 44
        }

        return heightForRowAt
    }

    fileprivate func calculateRowHeightForGroup(_ group: ReadiumShared.Group) -> CGFloat {
        if group.navigation.count > 0 {
            return tableView.bounds.height / 2

        } else {
            let idiom = { () -> UIUserInterfaceIdiom in
                let tempIdion = UIDevice.current.userInterfaceIdiom
                return (tempIdion != .pad) ? .phone : .pad // ignnore carplay and others
            }()

            guard let deviceLayoutHeightForRow = layoutHeightForRow[idiom] else { return 44 }
            guard let heightForRow = deviceLayoutHeightForRow[.current] else { return 44 }

            return heightForRow
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var title: String?

        switch browsingState {
        case .MixedGroup:
            if section >= 0, section <= feed!.groups.count {
                title = feed!.groups[section].metadata.title
            }

        case .MixedNavigationGroup:
            // Nav
            if section == 0 {
                title = NSLocalizedString("opds_browse_title", comment: "Title of the section displaying the feeds")
            }
            // Groups
            if section >= 1, section <= feed!.groups.count {
                title = feed!.groups[section - 1].metadata.title
            }

        case .MixedNavigationGroupPublication:
            if section == 0 {
                title = NSLocalizedString("opds_browse_title", comment: "Title of the section displaying the feeds")
            }
            if section >= 1, section <= feed!.groups.count {
                title = feed!.groups[section - 1].metadata.title
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

        var currentNavigation: [ReadiumShared.Link]?

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
                let group = ReadiumShared.Group(title: feed!.metadata.title)
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

    fileprivate func preparedGroupCell(group: ReadiumShared.Group?, indexPath: IndexPath, offset: Int) -> OPDSGroupTableViewCell {
        let castedCell = tableView.dequeueReusableCell(withIdentifier: "opdsGroupCell", for: indexPath) as! OPDSGroupTableViewCell
        castedCell.group = group != nil ? group : feed?.groups[indexPath.section - offset]
        castedCell.opdsRootTableViewController = self
        return castedCell
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch browsingState {
        case .Navigation, .MixedNavigationPublication, .MixedNavigationGroup, .MixedNavigationGroupPublication:
            var link: ReadiumShared.Link?
            if indexPath.section == 0 {
                link = feed!.navigation[indexPath.row]
            } else if indexPath.section >= 1, indexPath.section <= feed!.groups.count, feed!.groups[indexPath.section - 1].navigation.count > 0 {
                link = feed!.groups[indexPath.section - 1].navigation[indexPath.row]
            }

            if let link = link {
                pushOpdsRootViewController(href: link.href)
            }

        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.isAccessibilityElement = false

        header.textLabel?.font = UIFont.boldSystemFont(ofSize: 13)
        header.textLabel?.accessibilityHint = NSLocalizedString("opds_feed_header_a11y_hint", comment: "Accessibility hint feed section header")

        var offset: Int

        if browsingState != .MixedGroup {
            offset = section - 1
        } else {
            offset = section
        }

        if let feed = feed {
            if let moreButton = view.subviews.last as? OPDSMoreButton {
                if offset >= 0, offset < feed.groups.count {
                    moreButton.offset = offset
                } else {
                    view.subviews.last?.removeFromSuperview()
                }
                return
            }

            if offset >= 0, offset < feed.groups.count {
                let links = feed.groups[offset].links
                if links.count > 0 {
                    let buttonWidth: CGFloat = 70
                    let moreButton = OPDSMoreButton(type: .system)
                    moreButton.frame = CGRect(x: header.frame.width - buttonWidth, y: 0, width: buttonWidth, height: header.frame.height)

                    moreButton.setTitle(NSLocalizedString("opds_more_button", comment: "Button to expand a feed gallery"), for: .normal)
                    moreButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 11)
                    moreButton.setTitleColor(UIColor.darkGray, for: .normal)

                    moreButton.offset = offset
                    moreButton.addTarget(self, action: #selector(moreAction), for: .touchUpInside)

                    moreButton.isAccessibilityElement = true
                    moreButton.accessibilityLabel = NSLocalizedString("opds_more_button_a11y_label", comment: "Button to expand a feed gallery")

                    view.addSubview(moreButton)

                    moreButton.translatesAutoresizingMaskIntoConstraints = false
                    moreButton.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
                    moreButton.heightAnchor.constraint(equalToConstant: header.frame.height).isActive = true
                    moreButton.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
                }
            }
        }
    }

    // MARK: - Target action

    @objc func moreAction(sender: UIButton!) {
        if let moreButton = sender as? OPDSMoreButton {
            if let href = feed?.groups[moreButton.offset!].links[0].href {
                pushOpdsRootViewController(href: href)
            }
        }
    }
}

// MARK: - UINavigationController delegate and tooling

extension OPDSRootTableViewController: UINavigationControllerDelegate {
    fileprivate func pushOpdsRootViewController(href: String) {
        guard let url = URL(string: href) else {
            return
        }

        let viewController: OPDSRootTableViewController = factory.make(feedURL: url, indexPath: nil)
        navigationController?.pushViewController(viewController, animated: true)
    }
}

// MARK: - Sublass of UIButton

class OPDSMoreButton: UIButton {
    var offset: Int?
}
