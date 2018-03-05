//
//  OPDSFacetTableViewController.swift
//  r2-testapp-swift
//
//  Created by Nikita Aizikovskyi on Mar-05-2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import Foundation
import UIKit
import R2Shared

class OPDSFacetTableViewController : UITableViewController {
    var feed: Feed
    var catalogViewController: OPDSCatalogViewController

    init(feed: Feed, catalogViewController: OPDSCatalogViewController) {
        self.feed = feed
        self.catalogViewController = catalogViewController
        super.init(style: UITableViewStyle.plain)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feed.facets.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCellStyle.value1, reuseIdentifier: "facetCell")
        let facet = indexPath.row

        let facetName = feed.facets[facet].metadata.title
        cell.textLabel?.text = facetName

        if let facetValue = catalogViewController.getValueForFacet(facet: facet) {
            cell.detailTextLabel?.text = feed.facets[indexPath.row].links[facetValue].title
        }
        else {
            cell.detailTextLabel?.text = "-"
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.dismiss(animated: false, completion: nil)

        let facetIndex = indexPath.row
        let tableViewController = OPDSFacetChoiceTableViewController(facet: feed.facets[facetIndex], facetIndex: facetIndex, catalogViewController: catalogViewController)
        tableViewController.modalPresentationStyle = UIModalPresentationStyle.popover
        let popoverPresentationController = tableViewController.popoverPresentationController
        popoverPresentationController?.barButtonItem = catalogViewController.navigationItem.leftBarButtonItem
        catalogViewController.present(tableViewController, animated: false, completion: nil)
    }

}

