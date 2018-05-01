//
//  OPDSFacetTableViewController.swift
//  r2-testapp-swift
//
//  Created by Nikita Aizikovskyi on Mar-05-2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import UIKit
import R2Shared

class OPDSFacetViewController : UIViewController {
    var feed: Feed?
    var rootViewController: OPDSRootTableViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func dismissView(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - Table view datasource

extension OPDSFacetViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return feed!.facets.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feed!.facets[section].links.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "opdsFacetTableViewCell", for: indexPath)
        
        cell.textLabel?.text = feed!.facets[indexPath.section].links[indexPath.row].title
        if let count = feed!.facets[indexPath.section].links[indexPath.row].properties.numberOfItems {
            cell.detailTextLabel?.text  = "\(count)"
        } else {
            cell.detailTextLabel?.text  = ""
        }
        
        cell.textLabel?.font = UIFont.systemFont(ofSize: 14)
        cell.textLabel?.lineBreakMode = .byTruncatingTail
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12)
        
        return cell
    }
    
}

// MARK: - Table view delegate

extension OPDSFacetViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        rootViewController?.applyFacetAt(indexPath: indexPath)
        dismiss(animated: true, completion: nil)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return feed!.facets[section].metadata.title
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.boldSystemFont(ofSize: 15)
    }
    
}

