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

class DetailsTableViewController: UITableViewController {
    // Informations
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!

    weak var publication: Publication? = nil

    func setup(publication: Publication) {
        self.publication = publication
        modalPresentationStyle = .popover
    }

    override func viewDidLoad() {
        titleLabel.text = publication?.metadata.multilangTitle?.singleString
        idLabel.text = publication?.metadata.identifier
    }


}
