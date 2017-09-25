//
//  FontSelectionTableViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 9/20/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import UIKit

protocol FontSelectionDelegate {

}

class FontSelectionTableViewController: UITableViewController {
    var delegate: FontSelectionDelegate?
}
