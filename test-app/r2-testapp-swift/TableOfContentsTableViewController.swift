//
//  TableOfContentsTableViewController.swift
//  r2-navigator
//
//  Created by Alexandre Camilleri on 7/24/17.
//  Copyright © 2017 European Digital Reading Lab. All rights reserved.
//

import R2Shared
import R2Navigator
import UIKit

class TableOfContentsTableViewController: UITableViewController {
    var tableOfContents: [Link]
    var allElements = [Link]()
    var callBack: (String)->()

    init(for tableOfContents: [Link], callWhenDismissed: @escaping (String)->()) {
        self.tableOfContents = tableOfContents
        callBack = callWhenDismissed
        super.init(nibName: nil, bundle: nil)
        title = "Table Of Contents"
        tableView.delegate = self
        tableView.dataSource = self
        // Temporary - Get all the elements/subelements.
        for link in tableOfContents {
            let childs = childsOf(parent: link)

            // Append parent.
            allElements.append(link)
            // Append childs, and their childs... recursive.
            allElements.append(contentsOf: childs)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        guard let resourcePath = allElements[indexPath.row].href else {
            return
        }

        callBack(resourcePath)
        self.navigationController?.popViewController(animated: true)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "contentCell")

        cell.textLabel?.text = allElements[indexPath.row].title
        return cell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allElements.count
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = tableView.backgroundColor
        cell.tintColor = tableView.tintColor
        cell.textLabel?.textColor = tableView.tintColor
    }

    open override var prefersStatusBarHidden: Bool {
        return true
    }
}

extension TableOfContentsTableViewController {

    /// Synchronyze the UI appearance to the UserSettings.Appearance.
    ///
    /// - Parameter appearance: The appearance.
    public func setUIColor(for appearance: UserSettings.Appearance) {
        let color = appearance.associatedColor()
        let textColor = appearance.associatedFontColor()

        tableView.tintColor = textColor
        tableView.backgroundColor = color
        tableView.reloadData()
    }

    fileprivate func childsOf(parent: Link) -> [Link] {
        var childs = [Link]()

        for link in parent.children {
            childs.append(link)
            childs.append(contentsOf: childsOf(parent: link))
        }
        return childs
    }
}
