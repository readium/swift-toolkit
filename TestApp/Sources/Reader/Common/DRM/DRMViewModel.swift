//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared
import UIKit

/// Used to display a DRM license's informations
/// Should be subclassed for specific DRM.
class DRMViewModel: NSObject {
    /// Class cluster factory.
    /// Use this instead of regular constructors to create the right DRM view model.
    static func make(publication: Publication, presentingViewController: UIViewController) -> DRMViewModel {
        #if LCP
            if let license = publication.lcpLicense {
                return LCPViewModel(publication: publication, license: license, presentingViewController: presentingViewController)
            }
        #endif

        return DRMViewModel(publication: publication, presentingViewController: presentingViewController)
    }

    let publication: Publication

    /// Host view controller to be used to present any dialog.
    weak var presentingViewController: UIViewController?

    init(publication: Publication, presentingViewController: UIViewController) {
        assert(publication.isProtected)

        self.publication = publication
        self.presentingViewController = presentingViewController
    }

    var name: String? {
        publication.protectionName
    }

    var state: String? {
        nil
    }

    var provider: String? {
        nil
    }

    var issued: Date? {
        nil
    }

    var updated: Date? {
        nil
    }

    var start: Date? {
        nil
    }

    var end: Date? {
        nil
    }

    var copiesLeft: String {
        NSLocalizedString("reader_drm_unlimited_label", comment: "Unlimited quantity for a given DRM consumable right")
    }

    var printsLeft: String {
        NSLocalizedString("reader_drm_unlimited_label", comment: "Unlimited quantity for a given DRM consumable right")
    }

    var canRenewLoan: Bool {
        false
    }

    func renewLoan(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    var canReturnPublication: Bool {
        false
    }

    func returnPublication(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
}
