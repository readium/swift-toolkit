//
//  DetailsTableViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 11/20/17.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import R2Shared

protocol DetailsTableViewControllerFactory {
    func make(publication: Publication) -> DetailsTableViewController
}

final class DetailsTableViewController: UITableViewController {

    var publication: Publication!
    
    // Informations
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!

    override func viewDidLoad() {
        titleLabel.text = publication?.metadata.title
        idLabel.text = publication?.metadata.identifier
    }

}
