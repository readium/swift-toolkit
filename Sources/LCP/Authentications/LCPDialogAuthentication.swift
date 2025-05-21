//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UIKit

/// An `LCPAuthenticating` implementation presenting a dialog to the user.
///
/// For this authentication to trigger, you must provide a `sender` parameter of type
/// `UIViewController` to `Streamer.open()` or `LCPService.retrieveLicense()`. It will be used
/// as the presenting view controller for the dialog.
public class LCPDialogAuthentication: LCPAuthenticating, Loggable {
    private let animated: Bool
    private let modalPresentationStyle: UIModalPresentationStyle
    private let modalTransitionStyle: UIModalTransitionStyle

    public init(animated: Bool = true, modalPresentationStyle: UIModalPresentationStyle = .formSheet, modalTransitionStyle: UIModalTransitionStyle = .coverVertical) {
        self.animated = animated
        self.modalPresentationStyle = modalPresentationStyle
        self.modalTransitionStyle = modalTransitionStyle
    }

    public func retrievePassphrase(
        for license: LCPAuthenticatedLicense,
        reason: LCPAuthenticationReason,
        allowUserInteraction: Bool,
        sender: Any?
    ) async -> String? {
        guard allowUserInteraction, let viewController = sender as? UIViewController else {
            if !(sender is UIViewController) {
                log(.error, "Tried to present the LCP dialog without providing a `UIViewController` as `sender`")
            }
            return nil
        }

        return await withCheckedContinuation { continuation in
            let dialogViewController = LCPDialogViewController(license: license, reason: reason) { passphrase in
                continuation.resume(returning: passphrase)
            }

            let navController = UINavigationController(rootViewController: dialogViewController)
            navController.modalPresentationStyle = modalPresentationStyle
            navController.modalTransitionStyle = modalTransitionStyle

            viewController.present(navController, animated: animated)
        }
    }
}
