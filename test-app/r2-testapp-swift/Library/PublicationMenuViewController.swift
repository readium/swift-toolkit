//
//  PublicationMenuViewController.swift
//  r2-testapp-swift
//
//  Created by Geoffrey Bugniot on 30/07/2018.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//
//

import UIKit

protocol PublicationMenuViewControllerDelegate: AnyObject {
    func infosButtonTapped()
    func removeButtonTapped()
    func cancelButtonTapped()
}

class PublicationMenuViewController: UIViewController {
    
    weak var delegate: PublicationMenuViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func infosButtonTapped(_ sender: Any) {
        delegate?.infosButtonTapped()
    }
    
    @IBAction func removeButtonTapped(_ sender: Any) {
        delegate?.removeButtonTapped()
    }
    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        delegate?.cancelButtonTapped()
    }
    
}
