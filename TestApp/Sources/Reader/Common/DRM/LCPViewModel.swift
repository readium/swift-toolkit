//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

#if LCP

    import Foundation
    import R2Shared
    import ReadiumLCP
    import UIKit

    final class LCPViewModel: DRMViewModel {
        private let license: LCPLicense

        init(publication: Publication, license: LCPLicense, presentingViewController: UIViewController) {
            self.license = license
            super.init(publication: publication, presentingViewController: presentingViewController)
        }

        override var state: String? {
            license.status?.status.rawValue
        }

        override var provider: String? {
            license.license.provider
        }

        override var issued: Date? {
            license.license.issued
        }

        override var updated: Date? {
            license.license.updated
        }

        override var start: Date? {
            license.license.rights.start
        }

        override var end: Date? {
            license.license.rights.end
        }

        override var copiesLeft: String {
            guard let quantity = license.charactersToCopyLeft else {
                return super.copiesLeft
            }
            return String(format: NSLocalizedString("lcp_characters_label", comment: "Quantity of characters left to be copied"), quantity)
        }

        override var printsLeft: String {
            guard let quantity = license.pagesToPrintLeft else {
                return super.printsLeft
            }
            return String(format: NSLocalizedString("lcp_pages_label", comment: "Quantity of pages left to be printed"), quantity)
        }

        override var canRenewLoan: Bool {
            license.canRenewLoan
        }

        override func renewLoan(completion: @escaping (Error?) -> Void) {
            guard let presentingViewController = presentingViewController else {
                completion(nil)
                return
            }

            license.renewLoan(with: LCPDefaultRenewDelegate(presentingViewController: presentingViewController)) { result in
                switch result {
                case .success, .cancelled:
                    completion(nil)
                case let .failure(error):
                    completion(error)
                }
            }
        }

        override var canReturnPublication: Bool {
            license.canReturnPublication
        }

        override func returnPublication(completion: @escaping (Error?) -> Void) {
            license.returnPublication(completion: completion)
        }
    }

#endif
