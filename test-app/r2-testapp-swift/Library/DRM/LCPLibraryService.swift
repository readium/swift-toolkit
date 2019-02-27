//
//  LCPLibraryService.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 01.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

#if LCP

import Foundation
import SafariServices
import UIKit
import R2Shared
import ReadiumLCP


class LCPLibraryService: NSObject, DRMLibraryService {

    private var lcpService: LCPService!
    private var interactionsCallbacks: [Int: () -> Void] = [:]
    
    override init() {
        super.init()
        lcpService = R2MakeLCPService(interactionDelegate: self)
    }
    
    var brand: DRM.Brand {
        return .lcp
    }
    
    func canFulfill(_ file: URL) -> Bool {
        return file.pathExtension.lowercased() == "lcpl"
    }
    
    func fulfill(_ file: URL, completion: @escaping (CancellableResult<DRMFulfilledPublication>) -> Void) {
        lcpService.importPublication(from: file, authentication: self) { result, error in
            if let result = result {
                let publication = DRMFulfilledPublication(localURL: result.localURL, downloadTask: result.downloadTask, suggestedFilename: result.suggestedFilename)
                completion(.success(publication))
            } else if let error = error {
                completion(.failure(error))
            } else {
                completion(.cancelled)
            }
        }
    }
    
    func loadPublication(at publication: URL, drm: DRM, completion: @escaping (CancellableResult<DRM?>) -> Void) {
        lcpService.retrieveLicense(from: publication, authentication: self) { license, error in
            if let license = license {
                var drm = drm
                drm.license = license
                completion(.success(drm))
            } else if let error = error {
                completion(.failure(error))
            } else {
                completion(.cancelled)
            }
        }
    }
    
}

extension LCPLibraryService: LCPAuthenticating {
    
    func requestPassphrase(for license: LCPAuthenticatedLicense, reason: LCPAuthenticationReason, completion: @escaping (String?) -> Void) {
        guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
            completion(nil)
            return
        }
        
        let title: String
        switch reason {
        case .passphraseNotFound:
            title = "LCP Passphrase"
        case .invalidPassphrase:
            title = "The passphrase is incorrect"
        }
    
        let alert = UIAlertController(title: title, message: license.hint, preferredStyle: .alert)
        let dismissButton = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(nil)
        }
        let confirmButton = UIAlertAction(title: "Submit", style: .default) { _ in
            let passphrase = alert.textFields?[0].text
            completion(passphrase ?? "")
        }
    
        alert.addTextField { (textField) in
            textField.placeholder = "Passphrase"
            textField.isSecureTextEntry = true
        }
    
        alert.addAction(dismissButton)
        alert.addAction(confirmButton)
        viewController.present(alert, animated: true)
    }

}

extension LCPLibraryService: LCPInteractionDelegate {
    
    func presentLCPInteraction(at url: URL, dismissed: @escaping () -> Void) {
        guard let rootViewController = UIApplication.shared.delegate?.window??.rootViewController else {
            dismissed()
            return
        }
        
        let safariVC = SFSafariViewController(url: url)
        safariVC.delegate = self
        safariVC.modalPresentationStyle = .formSheet
        
        interactionsCallbacks[safariVC.hash] = dismissed
        rootViewController.present(safariVC, animated: true)
    }

}

extension LCPLibraryService: SFSafariViewControllerDelegate {
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        let dismissed = interactionsCallbacks.removeValue(forKey: controller.hash)
        dismissed?()
    }
    
}

#endif
