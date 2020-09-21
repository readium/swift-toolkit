//
//  LCPViewModel.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 19.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

#if LCP

import Foundation
import SafariServices
import R2Shared
import ReadiumLCP


final class LCPViewModel: DRMViewModel {

    private let license: LCPLicense
    
    init(publication: Publication, license: LCPLicense, presentingViewController: UIViewController) {
        self.license = license
        super.init(publication: publication, presentingViewController: presentingViewController)
    }
    
    override var state: String? {
        return license.status?.status.rawValue
    }
    
    override var provider: String? {
        return license.license.provider
    }
    
    override var issued: Date? {
        return license.license.issued
    }
    
    override var updated: Date? {
        return license.license.updated
    }
    
    override var start: Date? {
        return license.license.rights.start
    }
    
    override var end: Date? {
        return license.license.rights.end
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
        return license.canRenewLoan
    }
    
    private var renewCallbacks: [Int: () -> Void] = [:]
    
    override func renewLoan(completion: @escaping (Error?) -> Void) {
        func present(url: URL, dismissed: @escaping () -> Void) {
            guard let presentingViewController = self.presentingViewController else {
                dismissed()
                return
            }
            
            let safariVC = SFSafariViewController(url: url)
            safariVC.delegate = self
            safariVC.modalPresentationStyle = .formSheet
            
            renewCallbacks[safariVC.hash] = dismissed
            presentingViewController.present(safariVC, animated: true)
        }
        
        license.renewLoan(to: nil, present: present, completion: completion)
    }
    
    override var canReturnPublication: Bool {
        return license.canReturnPublication
    }
    
    override func returnPublication(completion: @escaping (Error?) -> Void) {
        license.returnPublication(completion: completion)
    }
    
}


extension LCPViewModel: SFSafariViewControllerDelegate {
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        let dismissed = renewCallbacks.removeValue(forKey: controller.hash)
        dismissed?()
    }
    
}

#endif
