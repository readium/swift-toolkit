//
//  LcpLibraryService.swift
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
import UIKit
import R2Shared
import ReadiumLCP


class LcpLibraryService: DrmLibraryService {

    private let lcpService: LcpService
    
    init() {
        self.lcpService = LcpService()
        self.lcpService.delegate = self
    }
    
    var brand: Drm.Brand {
        return .lcp
    }
    
    func canFulfill(_ file: URL) -> Bool {
        return file.pathExtension.lowercased() == "lcpl"
    }
    
    func fulfill(_ file: URL, completion: @escaping (CancellableResult<(URL, URLSessionDownloadTask?)>) -> Void) {
        lcpService.importLicenseDocument(file) { (result, error) in
            if case LcpError.cancelled? = error {
                completion(.cancelled)
                return
            }
            guard let result = result else {
                completion(.failure(error))
                return
            }
            
            completion(.success((result.localUrl, result.downloadTask)))
        }
    }
    
    func loadPublication(at publication: URL, drm: Drm, completion: @escaping (CancellableResult<Drm>) -> Void) {
        lcpService.openLicense(in: publication) { (license, error) in
            if case LcpError.cancelled? = error {
                completion(.cancelled)
                return
            }
            guard let license = license else {
                completion(.failure(error))
                return
            }
            
            var drm = drm
            drm.license = license
            drm.profile = license.profile
            completion(.success(drm))
        }
    }
    
    func removePublication(at publication: URL) {
        lcpService.removePublication(at: publication)
    }

}

extension LcpLibraryService: LcpServiceDelegate {
    
    func requestPassphrase(for license: LicenseDocument, reason: PassphraseRequestReason, completion: @escaping (String?) -> Void) {
        guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
            completion(nil)
            return
        }
        
        let title: String
        switch reason {
        case .notFound:
            title = "LCP Passphrase"
        case .invalid:
            title = "The passphrase is incorrect"
        }
    
        let message = license.getHint()
        let alert = UIAlertController(title: title,
                                      message: message, preferredStyle: .alert)
        let dismissButton = UIAlertAction(title: "Cancel", style: .cancel) { (_) in
            completion(nil)
        }
    
        let confirmButton = UIAlertAction(title: "Submit", style: .default) { (_) in
            let passphrase = alert.textFields?[0].text
            completion(passphrase ?? "")
        }
    
        //adding textfields to our dialog box
        alert.addTextField { (textField) in
            textField.placeholder = "Passphrase"
            textField.isSecureTextEntry = true
        }
    
        alert.addAction(dismissButton)
        alert.addAction(confirmButton)
        viewController.present(alert, animated: true)
    }

}

#endif
