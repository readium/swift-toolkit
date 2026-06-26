//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UIKit

/// Delegate presenting the passphrase dialog produced by `LCPDialogAuthentication``.
@MainActor public protocol LCPDialogAuthenticationDelegate: AnyObject, Sendable {
    /// Presents the LCP passphrase dialog view controller.
    ///
    /// The dialog dismisses itself once the user submits or cancels, so you only need to present it.
    func lcpDialogAuthentication(
        _ authentication: LCPDialogAuthentication,
        present dialogViewController: UIViewController
    )
}

/// An `LCPAuthenticating` implementation presenting a dialog to the user.
///
/// For this authentication to trigger, you must provide a ``delegate`` that
/// presents the dialog (for example on your top-most view controller).
public final class LCPDialogAuthentication: LCPAuthenticating, Loggable, Sendable {
    /// Delegate responsible for presenting the passphrase dialog.
    private weak var delegate: LCPDialogAuthenticationDelegate?

    private let modalPresentationStyle: UIModalPresentationStyle
    private let modalTransitionStyle: UIModalTransitionStyle

    public init(
        delegate: LCPDialogAuthenticationDelegate? = nil,
        modalPresentationStyle: UIModalPresentationStyle = .formSheet,
        modalTransitionStyle: UIModalTransitionStyle = .coverVertical
    ) {
        self.delegate = delegate
        self.modalPresentationStyle = modalPresentationStyle
        self.modalTransitionStyle = modalTransitionStyle
    }

    public func retrievePassphrase(
        for license: LCPAuthenticatedLicense,
        reason: LCPAuthenticationReason,
        allowUserInteraction: Bool
    ) async -> String? {
        guard allowUserInteraction, let delegate = delegate else {
            if delegate == nil {
                log(.error, "Tried to present the LCP dialog without providing a `delegate` to `LCPDialogAuthentication`")
            }
            return nil
        }

        return await withCheckedContinuation { continuation in
            let dialogViewController = LCPDialogViewController(license: license, reason: reason) { passphrase in
                continuation.resume(returning: passphrase)
            }
            dialogViewController.modalPresentationStyle = modalPresentationStyle
            dialogViewController.modalTransitionStyle = modalTransitionStyle
            delegate.lcpDialogAuthentication(self, present: dialogViewController)
        }
    }
}
