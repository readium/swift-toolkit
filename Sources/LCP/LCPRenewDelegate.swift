//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared
import SafariServices
import UIKit

/// UX delegate for the loan renew LSD interaction.
public protocol LCPRenewDelegate {
    /// Called when the renew interaction allows to customize the end date programmatically.
    ///
    /// You can prompt the user for the number of days to renew, for example.
    /// The returned date should not exceed `maximumDate`.
    func preferredEndDate(maximum: Date?, completion: @escaping (CancellableResult<Date?, Error>) -> Void)

    /// Called when the renew interaction uses an HTML web page.
    ///
    /// You should present the URL in a `SFSafariViewController` and call the `completion` callback when the browser
    /// is dismissed by the user.
    func presentWebPage(url: URL, completion: @escaping (CancellableResult<Void, Error>) -> Void)
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

    public func preferredEndDate(maximum: Date?, completion: @escaping (CancellableResult<Date?, Error>) -> Void) {
        completion(.success(nil))
    }

    public func presentWebPage(url: URL, completion: @escaping (CancellableResult<Void, Error>) -> Void) {
        let safariVC = SFSafariViewController(url: url)
        safariVC.modalPresentationStyle = modalPresentationStyle
        safariVC.presentationController?.delegate = self
        safariVC.delegate = self

        webPageCallback = completion
        presentingViewController.present(safariVC, animated: true)
    }

    private var webPageCallback: ((CancellableResult<Void, Error>) -> Void)? = nil
}

extension LCPDefaultRenewDelegate: UIAdaptivePresentationControllerDelegate {
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        webPageCallback?(.success(()))
        webPageCallback = nil
    }
}

extension LCPDefaultRenewDelegate: SFSafariViewControllerDelegate {
    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        webPageCallback?(.success(()))
        webPageCallback = nil
    }
}
