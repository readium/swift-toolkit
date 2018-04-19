//
//  OPDSCatalogSelectorViewController.swift
//  r2-testapp-swift
//
//  Created by Nikita Aizikovskyi on Mar-12-2018.
//  Copyright © 2018 Readium. All rights reserved.
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

    override func viewDidLoad() {
        catalogData = UserDefaults.standard.array(forKey: userDefaultsID) as? [[String: String]]
        if catalogData == nil {
            catalogData = [["title": "feedbooks", "url": "http://www.feedbooks.com/store/top.atom?category=FBFIC022000"]]
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

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return catalogData!.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:UITableViewCell = self.tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier) as UITableViewCell!
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
        let opdsCatalog = OPDSCatalogViewController(url: url)
        self.navigationController?.pushViewController(opdsCatalog!, animated: true)
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

    func showAddFeedPopup() {
        self.showEditPopup(feedIndex: nil)
    }

    func showEditPopup(feedIndex: Int?) {
        let alertController = UIAlertController(title: "Enter feed title and URL", message: "", preferredStyle: .alert)
        let confirmAction = UIAlertAction(title: "OK", style: .default) { (_) in
            let title = alertController.textFields?[0].text
            let url = alertController.textFields?[1].text
            if feedIndex == nil {
                self.catalogData?.append(["title": title!, "url": url!])
            }
            else {
                self.catalogData?[feedIndex!] = ["title": title!, "url": url!]
            }
            UserDefaults.standard.set(self.catalogData, forKey: self.userDefaultsID)
            self.tableView.reloadData()
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
