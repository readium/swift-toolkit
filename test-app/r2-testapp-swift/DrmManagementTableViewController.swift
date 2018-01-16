//
//  File.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 11/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import UIKit
import R2Shared
import PromiseKit

class DrmManagementTableViewController: UITableViewController {
    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var providerLabel: UILabel!
    @IBOutlet weak var issuedLabel: UILabel!
    @IBOutlet weak var updatedLabel: UILabel!
    //

    @IBOutlet weak var startLabel: UILabel!
    @IBOutlet weak var endLabel: UILabel!
    @IBOutlet weak var printsLeftLabel: UILabel!
    @IBOutlet weak var copiesLeftLabel: UILabel!
    //
    @IBOutlet weak var renewButton: UIButton!
    @IBOutlet weak var returnButton: UIButton!

    public var drm: Drm?

    override func viewWillAppear(_ animated: Bool) {
        title = "DRM Management"
        reload()
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
}
