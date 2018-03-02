//
//  DetailsTableViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 11/20/17.
//  Copyright © 2017 Readium. All rights reserved.
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
