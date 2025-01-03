//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import SafariServices
import UIKit

/// UX delegate for the loan renew LSD interaction.
public protocol LCPRenewDelegate {
    /// Called when the renew interaction allows to customize the end date programmatically.
    ///
    /// You can prompt the user for the number of days to renew, for example.
    /// The returned date should not exceed `maximumDate`.
    func preferredEndDate(maximum: Date?) async throws -> Date?

    /// Called when the renew interaction uses an HTML web page.
    ///
    /// You should present the URL in a `SFSafariViewController` and call the `completion` callback when the browser
    /// is dismissed by the user.
    func presentWebPage(url: HTTPURL) async throws
}

/// Default `LCPRenewDelegate` implementation using standard views.
///
/// No date picker is presented for selecting a preferred end date. If you want to support one, you can subclass or
/// decorate `LCPRenewDelegate`.
public class LCPDefaultRenewDelegate: NSObject, LCPRenewDelegate {
    private let presentingViewController: UIViewController
    private let modalPresentationStyle: UIModalPresentationStyle

    public init(presentingViewController: UIViewController, modalPresentationStyle: UIModalPresentationStyle = .formSheet) {
        self.presentingViewController = presentingViewController
        self.modalPresentationStyle = modalPresentationStyle
    }

    public func preferredEndDate(maximum: Date?) async throws -> Date? {
        nil
    }

    @MainActor
    public func presentWebPage(url: HTTPURL) async throws {
        await withCheckedContinuation { continuation in
            webPageContinuation = continuation

            let safariVC = SFSafariViewController(url: url.url)
            safariVC.modalPresentationStyle = modalPresentationStyle
            safariVC.presentationController?.delegate = self
            safariVC.delegate = self
            presentingViewController.present(safariVC, animated: true)
        }
    }

    private var webPageContinuation: CheckedContinuation<Void, Never>? = nil
}

extension LCPDefaultRenewDelegate: UIAdaptivePresentationControllerDelegate {
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        webPageContinuation?.resume(returning: ())
        webPageContinuation = nil
    }
}

extension LCPDefaultRenewDelegate: SFSafariViewControllerDelegate {
    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        webPageContinuation?.resume(returning: ())
        webPageContinuation = nil
    }
}
