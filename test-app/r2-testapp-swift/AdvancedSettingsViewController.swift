//
//  AdvancedSettingsViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 9/20/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import UIKit

protocol AdvancedSettingsDelegate {

}

class AdvancedSettingsViewController: UIViewController {
    var delegate: AdvancedSettingsDelegate?

    @IBAction func backTapped() {
        dismiss(animated: true, completion: nil)
    }
}
