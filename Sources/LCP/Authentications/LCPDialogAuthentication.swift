//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UIKit

/// Delegate presenting the passphrase dialog produced by
/// `LCPDialogAuthentication`.
@MainActor public protocol LCPDialogAuthenticationDelegate: AnyObject, Sendable {
    /// Presents the LCP passphrase dialog view controller.
    ///
    /// The dialog dismisses itself once the user submits or cancels, so you
    /// only need to present it.
    func lcpDialogAuthentication(
        _ authentication: LCPDialogAuthentication,
        present dialogViewController: UIViewController
    )
}

/// An `LCPAuthenticating` implementation presenting a dialog to the user.
///
/// For this authentication to trigger, you must provide a ``delegate`` that
/// presents the dialog (for example on your top-most view controller).
@MainActor
public final class LCPDialogAuthentication: LCPAuthenticating, Loggable {
    /// Delegate responsible for presenting the passphrase dialog.
    private weak var delegate: LCPDialogAuthenticationDelegate?

    public init(delegate: LCPDialogAuthenticationDelegate) {
        self.delegate = delegate
    }

    public func retrievePassphrase(
        for license: LCPAuthenticatedLicense,
        reason: LCPAuthenticationReason,
        allowUserInteraction: Bool
    ) async -> String? {
        guard allowUserInteraction else {
            return nil
        }
        guard let delegate = delegate else {
            log(.error, "The `LCPDialogAuthentication` delegate was deallocated before it could present the passphrase dialog. Make sure you retain it for the lifetime of the authentication.")
            return nil
        }

        return await withCheckedContinuation { continuation in
            let dialogViewController = LCPDialogViewController(license: license, reason: reason) { passphrase in
                continuation.resume(returning: passphrase)
            }
            delegate.lcpDialogAuthentication(self, present: dialogViewController)
        }
    }

    @available(*, unavailable, message: "Set the modal presentation and transition styles from your LCPDialogAuthenticationDelegate implementation")
    public convenience init(
        modalPresentationStyle: UIModalPresentationStyle = .formSheet,
        modalTransitionStyle: UIModalTransitionStyle = .coverVertical
    ) {
        fatalError()
    }
}
