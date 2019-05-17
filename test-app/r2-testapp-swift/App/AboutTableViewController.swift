//
//  AboutTableViewController.swift
//  r2-testapp-swift
//
//  Created by Geoffrey Bugniot on 27/04/2018.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import UIKit


class AboutTableViewController: UITableViewController {

    @IBOutlet weak var versionNumberCell: UITableViewCell!
    @IBOutlet weak var buildNumberCell: UITableViewCell!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            versionNumberCell.textLabel?.text = "App Version:"
            versionNumberCell.detailTextLabel?.text = "\(version)"
        } else {
            versionNumberCell.textLabel?.text = "App Version:"
            versionNumberCell.detailTextLabel?.text = "unknown"
        }
      
        if let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
          buildNumberCell.textLabel?.text = "Build Version:"
          buildNumberCell.detailTextLabel?.text = "\(version)"
        } else {
          buildNumberCell.textLabel?.text = "Build Version:"
          buildNumberCell.detailTextLabel?.text = "unknown"
        }
      
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var url: URL?
        
        if indexPath.section == 1 {
            if indexPath.row == 0 {
                url = URL(string: "https://www.edrlab.org/")
            } else {
                url = URL(string: "https://opensource.org/licenses/BSD-3-Clause")
            }
        }
        
        if let url = url {
            UIApplication.shared.openURL(url)
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
}
