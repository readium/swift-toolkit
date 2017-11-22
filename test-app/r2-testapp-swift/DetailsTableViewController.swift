//
//  DetailsTableViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 11/20/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import UIKit
import R2Shared
import ReadiumLCP

class DetailsTableViewController: UITableViewController {
    // Informations
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    // DRM
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var loanStatusLabel: UILabel!
    weak var publication: Publication? = nil
    var drm: Drm? = nil

    func setup(publication: Publication, drm: Drm?) {
        self.publication = publication
        self.drm = drm
        modalPresentationStyle = .popover
    }

    override func viewDidLoad() {
        titleLabel.text = publication?.metadata.multilangTitle?.singleString
        idLabel.text = publication?.metadata.identifier
        typeLabel.text = drm?.brand.rawValue
//        LCPDatabase.shared
        statusLabel.text = "unknown"
        loanStatusLabel.text = "unknown"
        // USE db
    }

    
    @IBAction func renewTapped() {
        print("TAPPER")
    }

    @IBAction func returnTapped() {
        print("du")
    }


}
