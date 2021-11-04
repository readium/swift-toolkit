//
//  DRMManagementTableViewController.swift
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
import R2Shared
import R2Navigator

protocol DRMManagementTableViewControllerFactory {
    func make(publication: Publication, delegate: ReaderModuleDelegate?) -> DRMManagementTableViewController
}

class DRMManagementTableViewController: UITableViewController {
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
    
    public var viewModel: DRMViewModel!
    public var appearance: UserProperty?
    
    weak var moduleDelegate: ReaderModuleDelegate?
    
    override func viewWillAppear(_ animated: Bool) {
        title = NSLocalizedString("reader_drm_management_title", comment: "Title of the DRM management view")
        reload()
        self.navigationController?.navigationBar.barTintColor = UIColor.white
        self.navigationController?.navigationBar.tintColor = UIColor.black
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.black]
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
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: colors.textColor]
    }
      
    @IBAction func renewTapped() {
        let alert = UIAlertController(
            title: NSLocalizedString("reader_drm_renew_title", comment: "Title of the renew confirmation alert"),
            message: NSLocalizedString("reader_drm_renew_message", comment: "Message of the renew confirmation alert"),
            preferredStyle: .alert
        )
        let confirmButton = UIAlertAction(title: NSLocalizedString("confirm_button", comment: "Confirmation button to renew a publication"), style: .default, handler: { (_) in
            self.viewModel.renewLoan { error in
                if let error = error {
                    self.moduleDelegate?.presentError(error, from: self)
                } else {
                    self.reload()
                    self.moduleDelegate?.presentAlert(
                        NSLocalizedString("success_title", comment: "Title for the success message after renewing a publication"),
                        message: NSLocalizedString("reader_drm_renew_success_message", comment: "Success message after renewing a publication"),
                        from: self
                    )
                }
            }
        })
        let dismissButton = UIAlertAction(title: NSLocalizedString("cancel_button", comment: "Cancel renewing the publication"), style: .cancel)
        
        alert.addAction(dismissButton)
        alert.addAction(confirmButton)
        // Present alert.
        present(alert, animated: true)
    }
    
    @IBAction func returnTapped() {
        let alert = UIAlertController(
            title: NSLocalizedString("reader_drm_return_title", comment: "Title of the return confirmation alert"),
            message: NSLocalizedString("reader_drm_return_message", comment: "Message of the return confirmation alert"),
            preferredStyle: .alert
        )
        let confirmButton = UIAlertAction(title: NSLocalizedString("confirm_button", comment: "Confirmation button to return a publication"), style: .destructive, handler: { (_) in
            self.viewModel.returnPublication() { error in
                if let error = error {
                    self.moduleDelegate?.presentError(error, from: self)
                } else {
                    self.navigationController?.popToRootViewController(animated: true)
                    self.moduleDelegate?.presentAlert(
                        NSLocalizedString("success_title", comment: "Title for the success message after returning a publication"),
                        message: NSLocalizedString("reader_drm_return_success_message", comment: "Success message after returning a publication"),
                        from: self
                    )
                }
            }
        })
        let dismissButton = UIAlertAction(title: NSLocalizedString("cancel_button", comment: "Cancel returning the publication"), style: .cancel)
        
        alert.addAction(dismissButton)
        alert.addAction(confirmButton)
        // Present alert.
        present(alert, animated: true)
        
    }
    
    internal func reload() {
        typeLabel.text = viewModel.name
        stateLabel.text = viewModel.state
        providerLabel.text = viewModel.provider
        issuedLabel.text = viewModel.issued?.description
        updatedLabel.text = viewModel.updated?.description
        startLabel.text = viewModel.start?.description ?? "-"
        endLabel.text = viewModel.end?.description ?? "-"
        printsLeftLabel.text = viewModel.printsLeft
        copiesLeftLabel.text = viewModel.copiesLeft
        renewButton.isEnabled = viewModel.canRenewLoan
        returnButton.isEnabled = viewModel.canReturnPublication
    }

}
