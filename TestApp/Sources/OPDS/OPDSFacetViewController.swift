//
//  OPDSFacetViewController.swift
//  r2-testapp-swift
//
//  Created by Nikita Aizikovskyi on Mar-05-2018.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import R2Shared


protocol OPDSFacetViewControllerFactory {
    func make(feed: Feed) -> OPDSFacetViewController
}

protocol OPDSFacetViewControllerDelegate: AnyObject {
    func opdsFacetViewController(_ opdsFacetViewController: OPDSFacetViewController, presentOPDSFeedAt href: String)
}

final class OPDSFacetViewController : UIViewController {
    var feed: Feed!
    weak var delegate: OPDSFacetViewControllerDelegate?

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
        return feed.facets.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feed.facets[section].links.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "opdsFacetTableViewCell", for: indexPath)
        
        cell.textLabel?.text = feed.facets[indexPath.section].links[indexPath.row].title
        if let count = feed.facets[indexPath.section].links[indexPath.row].properties.numberOfItems {
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
        let href = feed.facets[indexPath.section].links[indexPath.row].href
        delegate?.opdsFacetViewController(self, presentOPDSFeedAt: href)
        dismiss(animated: true, completion: nil)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return feed.facets[section].metadata.title
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.boldSystemFont(ofSize: 15)
    }
    
}

