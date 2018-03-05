//
//  OPDSFacetChoiceTableViewController.swift
//  r2-testapp-swift
//
//  Created by Nikita Aizikovskyi on Mar-05-2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import Foundation
import UIKit
import R2Shared

class OPDSFacetChoiceTableViewController : UITableViewController {
    var facet: Facet
    var facetIndex: Int
    var catalogViewController: OPDSCatalogViewController

    init(facet: Facet, facetIndex: Int, catalogViewController: OPDSCatalogViewController) {
        self.facet = facet
        self.facetIndex = facetIndex
        self.catalogViewController = catalogViewController
        super.init(style: UITableViewStyle.plain)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return facet.links.count + 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCellStyle.value1, reuseIdentifier: "facetChoiceCell")
        let linkIndex = indexPath.row - 1

        var facetName = "-"
        if (linkIndex >= 0) {
            facetName = facet.links[linkIndex].title ?? "none"
        }
        cell.textLabel?.text = facetName
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let linkIndex: Int? = indexPath.row == 0 ? nil : (indexPath.row - 1)
        catalogViewController.setValueForFacet(facet: facetIndex, value: linkIndex)
        self.dismiss(animated: true, completion: nil)
    }
}
