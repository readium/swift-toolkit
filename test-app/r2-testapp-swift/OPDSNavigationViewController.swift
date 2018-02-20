//
//  OPDSNavigationViewController.swift
//  r2-testapp-swift
//
//  Created by Nikita Aizikovskyi on Feb-13-2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import UIKit
import Foundation
import R2Shared
import ReadiumOPDS

class OPDSNavigationViewController: UITableViewController {
    var links: [Link]

    init?(feed: Feed) {
        self.links = feed.navigation
        super.init(style: UITableViewStyle.plain)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        guard let resourcePath = links[indexPath.row].href else {
            return
        }
        // navigate to new path
        print("Navigating to " + resourcePath)
    }

    override func viewDidLoad() {
        tableView.isScrollEnabled = false
        tableView.sizeToFit()
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "contentCell")
        cell.textLabel?.text = links[indexPath.row].title
        return cell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return links.count
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = tableView.backgroundColor
        cell.tintColor = tableView.tintColor
        cell.textLabel?.textColor = tableView.tintColor
    }

    open override var prefersStatusBarHidden: Bool {
        return true
    }}
