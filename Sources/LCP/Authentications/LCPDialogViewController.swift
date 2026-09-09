//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI
import UIKit

final class LCPDialogViewController: UIViewController {
    private let license: LCPAuthenticatedLicense
    private let reason: LCPAuthenticationReason
    private let completion: (String?) -> Void

    init(license: LCPAuthenticatedLicense, reason: LCPAuthenticationReason, completion: @escaping (String?) -> Void) {
        self.license = license
        self.reason = reason
        self.completion = completion
        super.init(nibName: nil, bundle: nil)

        isModalInPresentation = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let dialog = LCPDialog(
            hint: license.hint.orNilIfBlank(),
            errorMessage: reason == .invalidPassphrase ? .incorrectPassphrase : nil,
            onSubmit: { [weak self] passphrase in
                self?.complete(with: passphrase)
            },
            onForgotPassphrase: license.hintLink?.url().map { url in
                { UIApplication.shared.open(url.url) }
            },
            onCancel: { [weak self] in
                self?.complete(with: nil)
            }
        )

        let hostingController = UIHostingController(rootView: dialog)
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingController.didMove(toParent: self)
    }

    private var isCompleted = false

    private func complete(with passphrase: String?) {
        guard !isCompleted else {
            return
        }
        isCompleted = true

        guard presentingViewController != nil else {
            completion(passphrase)
            return
        }

        // The completion must be called only after the dialog is fully
        // dismissed. Otherwise, when retrying an invalid passphrase, the next
        // dialog might be presented while this one is still animating its
        // dismissal, which fails and leaks the caller's continuation.
        dismiss(animated: true) {
            self.completion(passphrase)
        }
    }

    isolated deinit {
        // Safety net: if the dialog is deallocated without being submitted or
        // cancelled (e.g. the delegate failed to present it), we still need
        // to call the completion to avoid leaking the caller's continuation.
        if !isCompleted {
            completion(nil)
        }
    }
}
