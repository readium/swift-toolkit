//
//  DrmManagementTableViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 11/27/17.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import PromiseKit
import R2Shared
import R2Navigator

class DrmManagementTableViewController: UITableViewController {
    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var providerLabel: UILabel!
    @IBOutlet weak var issuedLabel: UILabel!
    @IBOutlet weak var updatedLabel: UILabel!
    
    @IBOutlet weak var startLabel: UILabel!
    @IBOutlet weak var endLabel: UILabel!
    @IBOutlet weak var printsLeftLabel: UILabel!
    @IBOutlet weak var copiesLeftLabel: UILabel!
    
    @IBOutlet weak var renewButton: UIButton!
    @IBOutlet weak var returnButton: UIButton!
    
    public var drm: Drm?
    public var appearance: UserProperty?
    
    override func viewWillAppear(_ animated: Bool) {
        title = "DRM Management"
        reload()
        self.navigationController?.navigationBar.barTintColor = UIColor.white
        self.navigationController?.navigationBar.tintColor = UIColor.black
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.black]
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if let appearance = appearance{
            setUIColor(for: appearance)
        }
        super.viewWillDisappear(animated)
    }
    
    internal func setUIColor(for appearance: UserProperty) {
        let colors = AssociatedColors.getColors(for: appearance)
        
        navigationController?.navigationBar.barTintColor = colors.mainColor
        navigationController?.navigationBar.tintColor = colors.textColor
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: colors.textColor]
    }
    
    open override var prefersStatusBarHidden: Bool {
        return true
    }
    
    @IBAction func renewTapped() {
        let alert = UIAlertController(title: "Renew License",
                                      message: "The provider will receive you query and process it.",
                                      preferredStyle: .alert)
        let confirmButton = UIAlertAction(title: "Confirm", style: .default, handler: { (_) in
            // Make endate selection. let server decide date.
            self.drm?.license?.renew(endDate: nil, completion: { error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.infoAlert(title: "Error", message: error.localizedDescription)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.reload()
                        self.infoAlert(title: "Succes", message: "Publication renewed successfully.")
                    }
                }
            })
        })
        let dismissButton = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(dismissButton)
        alert.addAction(confirmButton)
        // Present alert.
        present(alert, animated: true)
    }
    
    @IBAction func returnTapped() {
        let alert = UIAlertController(title: "Return License",
                                      message: "Returning the loan will prevent you from accessing the publication.",
                                      preferredStyle: .alert)
        let confirmButton = UIAlertAction(title: "Confirm", style: .destructive, handler: { (_) in
            self.drm?.license?.`return`(completion: { error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.infoAlert(title: "Error", message: error.localizedDescription)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.navigationController?.popToRootViewController(animated: true)
                        self.infoAlert(title: "Succes", message: "Publication returned successfully.")
                    }
                }
            })
        })
        let dismissButton = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(dismissButton)
        alert.addAction(confirmButton)
        // Present alert.
        present(alert, animated: true)
        
    }
    
    internal func reload() {
        guard let drm = drm else {
            return
        }
        typeLabel.text = drm.brand.rawValue
        stateLabel.text = drm.license?.currentStatus()
        providerLabel.text = drm.license?.provider().absoluteString
        issuedLabel.text = drm.license?.issued().description
        updatedLabel.text = drm.license?.lastUpdate().description
        startLabel.text = drm.license?.rightsStart()?.description
        endLabel.text = drm.license?.rightsEnd()?.description
        if let prints = drm.license?.rightsPrints() {
            printsLeftLabel.text =  String(prints)
        }
        if let copies = drm.license?.rightsCopies() {
            copiesLeftLabel.text = String(copies)
        }
    }
    
    internal func infoAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let dismissButton = UIAlertAction(title: "Ok", style: .cancel)
        
        alert.addAction(dismissButton)
        // Present alert.
        present(alert, animated: true)
    }
    
    // MARK: - UITableView
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        let count = super.numberOfSections(in: tableView)
        if drm?.license?.rightsEnd() == nil {
            // remove last section
            return count - 1
        }
        return count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = super.tableView(tableView, numberOfRowsInSection: section)
        if (section == 1 && drm?.license?.rightsEnd() == nil) {
            // remove last two rows
            return count - 2
        }
        return count
    }
}
