//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumNavigator
import ReadiumShared
import UIKit

#if LCP

    protocol LCPManagementTableViewControllerFactory {
        func make(publication: Publication, delegate: ReaderModuleDelegate?) -> LCPManagementTableViewController?
    }

    class LCPManagementTableViewController: UITableViewController {
        @IBOutlet var stateLabel: UILabel!
        @IBOutlet var typeLabel: UILabel!
        @IBOutlet var providerLabel: UILabel!
        @IBOutlet var issuedLabel: UILabel!
        @IBOutlet var updatedLabel: UILabel!

        @IBOutlet var startLabel: UILabel!
        @IBOutlet var endLabel: UILabel!
        @IBOutlet var printsLeftLabel: UILabel!
        @IBOutlet var copiesLeftLabel: UILabel!

        @IBOutlet var renewButton: UIButton!
        @IBOutlet var returnButton: UIButton!

        public var viewModel: LCPViewModel!

        weak var moduleDelegate: ReaderModuleDelegate?

        override func viewWillAppear(_ animated: Bool) {
            title = NSLocalizedString("reader_drm_management_title", comment: "Title of the DRM management view")
            reload()
        }

        @IBAction func renewTapped() {
            let alert = UIAlertController(
                title: NSLocalizedString("reader_drm_renew_title", comment: "Title of the renew confirmation alert"),
                message: NSLocalizedString("reader_drm_renew_message", comment: "Message of the renew confirmation alert"),
                preferredStyle: .alert
            )
            let confirmButton = UIAlertAction(title: NSLocalizedString("confirm_button", comment: "Confirmation button to renew a publication"), style: .default, handler: { _ in
                Task {
                    do {
                        try await self.viewModel.renewLoan()
                        self.reload()
                        self.moduleDelegate?.presentAlert(
                            NSLocalizedString("success_title", comment: "Title for the success message after renewing a publication"),
                            message: NSLocalizedString("reader_drm_renew_success_message", comment: "Success message after renewing a publication"),
                            from: self
                        )

                    } catch {
                        self.moduleDelegate?.presentError(UserError(error), from: self)
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
            let confirmButton = UIAlertAction(title: NSLocalizedString("confirm_button", comment: "Confirmation button to return a publication"), style: .destructive, handler: { _ in
                Task {
                    do {
                        try await self.viewModel.returnPublication()

                        self.navigationController?.popToRootViewController(animated: true)
                        self.moduleDelegate?.presentAlert(
                            NSLocalizedString("success_title", comment: "Title for the success message after returning a publication"),
                            message: NSLocalizedString("reader_drm_return_success_message", comment: "Success message after returning a publication"),
                            from: self
                        )

                    } catch {
                        self.moduleDelegate?.presentError(UserError(error), from: self)
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
            typeLabel.text = "Readium LCP"
            stateLabel.text = viewModel.state
            providerLabel.text = viewModel.provider
            issuedLabel.text = viewModel.issued?.description
            updatedLabel.text = viewModel.updated?.description
            startLabel.text = viewModel.start?.description ?? "-"
            endLabel.text = viewModel.end?.description ?? "-"
            renewButton.isEnabled = viewModel.canRenewLoan
            returnButton.isEnabled = viewModel.canReturnPublication

            Task {
                printsLeftLabel.text = await viewModel.printsLeft()
                copiesLeftLabel.text = await viewModel.copiesLeft()
            }
        }
    }

#endif
