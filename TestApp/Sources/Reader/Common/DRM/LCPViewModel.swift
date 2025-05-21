//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

#if LCP

    import Foundation
    import ReadiumLCP
    import ReadiumShared
    import UIKit

    final class LCPViewModel {
        private let license: LCPLicense

        /// Host view controller to be used to present any dialog.
        private weak var presentingViewController: UIViewController?

        init(license: LCPLicense, presentingViewController: UIViewController) {
            self.license = license
            self.presentingViewController = presentingViewController
        }

        var state: String? {
            license.status?.status.rawValue
        }

        var provider: String? {
            license.license.provider
        }

        var issued: Date? {
            license.license.issued
        }

        var updated: Date? {
            license.license.updated
        }

        var start: Date? {
            license.license.rights.start
        }

        var end: Date? {
            license.license.rights.end
        }

        func copiesLeft() async -> String {
            guard let quantity = await license.charactersToCopyLeft() else {
                return NSLocalizedString("reader_drm_unlimited_label", comment: "Unlimited quantity for a given DRM consumable right")
            }
            return String(format: NSLocalizedString("lcp_characters_label", comment: "Quantity of characters left to be copied"), quantity)
        }

        func printsLeft() async -> String {
            guard let quantity = await license.pagesToPrintLeft() else {
                return NSLocalizedString("reader_drm_unlimited_label", comment: "Unlimited quantity for a given DRM consumable right")
            }
            return String(format: NSLocalizedString("lcp_pages_label", comment: "Quantity of pages left to be printed"), quantity)
        }

        var canRenewLoan: Bool {
            license.canRenewLoan
        }

        func renewLoan() async throws {
            guard let presentingViewController = presentingViewController else {
                return
            }

            try await license.renewLoan(with: LCPDefaultRenewDelegate(presentingViewController: presentingViewController)).get()
        }

        var canReturnPublication: Bool {
            license.canReturnPublication
        }

        func returnPublication() async throws {
            try await license.returnPublication().get()
        }
    }

#endif
