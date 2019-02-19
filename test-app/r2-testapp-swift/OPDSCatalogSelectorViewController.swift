//
//  OPDSCatalogSelectorViewController.swift
//  r2-testapp-swift
//
//  Created by Nikita Aizikovskyi on Mar-12-2018.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import Foundation
import R2Shared
import ReadiumOPDS

class OPDSCatalogSelectorViewController: UITableViewController {
    var catalogData: [[String: String]]? // An array of dicts in the form ["title": title, "url": url]
    let cellReuseIdentifier = "catalogSelectorCell"
    let userDefaultsID = "opdsCatalogArray"
    var addFeedButton: UIBarButtonItem?
    var mustEditAtIndexPath: IndexPath?

    override func viewDidLoad() {
        catalogData = UserDefaults.standard.array(forKey: userDefaultsID) as? [[String: String]]
        if catalogData == nil {
            catalogData = [
                ["title": "Feedbooks", "url": "http://www.feedbooks.com/catalog.atom"],
                ["title": "Open Textbooks", "url": "http://open.minitex.org"]
            ]
            UserDefaults.standard.set(catalogData, forKey: userDefaultsID)
        }
        
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)

        self.tableView.frame = UIScreen.main.bounds
        tableView.layoutMargins = UIEdgeInsets.zero
        tableView.separatorInset = UIEdgeInsets.zero
        tableView.cellLayoutMarginsFollowReadableWidth = false
        tableView.sizeToFit()

        addFeedButton = UIBarButtonItem(title: "Add", style: UIBarButtonItemStyle.plain, target: self, action: #selector(OPDSCatalogSelectorViewController.showAddFeedPopup))
        navigationItem.rightBarButtonItem = addFeedButton
        
        navigationController?.navigationBar.tintColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        navigationController?.navigationBar.barTintColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        navigationController?.view.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if let index = mustEditAtIndexPath?.row {
            showEditPopup(feedIndex: index)
        }
        mustEditAtIndexPath = nil
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return catalogData!.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
        cell.textLabel?.text = catalogData![indexPath.row]["title"]
        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        tableView.layoutMargins = UIEdgeInsets.zero
        tableView.separatorInset = UIEdgeInsets.zero
        cell.layoutMargins = UIEdgeInsets.zero
        cell.separatorInset = UIEdgeInsets.zero
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: false)
        guard let urlString = catalogData![indexPath.row]["url"],
            let url = URL(string: urlString) else {
                return
        }
      
        let opdsStoryboard = UIStoryboard(name: "OPDS", bundle: nil)
        let opdsRootViewController = opdsStoryboard.instantiateViewController(withIdentifier: "opdsRootViewController") as? OPDSRootTableViewController
        if let opdsRootViewController = opdsRootViewController {
            opdsRootViewController.originalFeedURL = url
            opdsRootViewController.originalFeedIndexPath = indexPath
            navigationController?.pushViewController(opdsRootViewController, animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {

        // action one
        let editAction = UITableViewRowAction(style: .default, title: "Edit", handler: { (action, indexPath) in
            self.showEditPopup(feedIndex: indexPath.row)
        })
        editAction.backgroundColor = UIColor.gray

        // action two
        let deleteAction = UITableViewRowAction(style: .default, title: "Delete", handler: { (action, indexPath) in
            self.catalogData?.remove(at: indexPath.row)
            UserDefaults.standard.set(self.catalogData, forKey: self.userDefaultsID)
            self.tableView.reloadData()
        })
        deleteAction.backgroundColor = UIColor.gray

        return [editAction, deleteAction]
    }

    @objc func showAddFeedPopup() {
        self.showEditPopup(feedIndex: nil)
    }

    func showEditPopup(feedIndex: Int?, retry: Bool = false) {
        let alertController = UIAlertController(title: "Enter feed title and URL",
                                                message: retry ? "Feed is not valid, please try again." : "",
                                                preferredStyle: .alert)
        let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
            let title = alertController.textFields?[0].text
            let urlString = alertController.textFields?[1].text
            if let url = URL(string: urlString!) {
                OPDSParser.parseURL(url: url) { _, error in
                    DispatchQueue.main.async {
                        guard error == nil  else {
                            self.showEditPopup(feedIndex: feedIndex, retry: true)
                            return
                        }

                        if feedIndex == nil {
                            self.catalogData?.append(["title": title!, "url": urlString!])
                        }
                        else {
                            self.catalogData?[feedIndex!] = ["title": title!, "url": urlString!]
                        }
                        UserDefaults.standard.set(self.catalogData, forKey: self.userDefaultsID)
                        self.tableView.reloadData()
                    }
                }
            } else {
                self.showEditPopup(feedIndex: feedIndex, retry: true)
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
        alertController.addTextField {(textField) in
            textField.placeholder = "Feed Title"
            if feedIndex != nil {
                textField.text = self.catalogData![feedIndex!]["title"]
            }
        }
        alertController.addTextField {(textField) in
            textField.placeholder = "Feed URL"
            if feedIndex != nil {
                textField.text = self.catalogData![feedIndex!]["url"]
            }
        }
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
}
