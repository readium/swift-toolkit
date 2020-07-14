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
import UIKit
import R2Shared
import ReadiumLCP


class LCPLibraryService: DRMLibraryService {

    private var lcpService = R2MakeLCPService()
    
    /// [LicenseDocument.id: passphrase callback]
    private var authenticationCallbacks: [String: (String?) -> Void] = [:]

    var brand: DRM.Brand {
        return .lcp
    }
    
    func canFulfill(_ file: URL) -> Bool {
        return file.pathExtension.lowercased() == "lcpl"
    }
    
    func fulfill(_ file: URL, completion: @escaping (CancelableResult<DRMFulfilledPublication, Error>) -> Void) {
        lcpService.importPublication(from: file, authentication: self) { result in
            let publication = CancelableResult(result)
                .map {
                    DRMFulfilledPublication(
                        localURL: $0.localURL,
                        downloadTask: $0.downloadTask,
                        suggestedFilename: $0.suggestedFilename)
                }
                .mapError { $0 as Error }
            
            completion(publication)
        }
    }
    
    func loadPublication(at publication: URL, drm: DRM, completion: @escaping (CancelableResult<DRM?, Error>) -> Void) {
        lcpService.retrieveLicense(from: publication, authentication: self) { result in
            let result = CancelableResult(result)
                .map { license -> DRM? in
                    var drm = drm
                    drm.license = license
                    return drm
                }
                .mapError { $0 as Error }

            completion(result)
        }
    }
    
}

extension LCPLibraryService: LCPAuthenticating {
    
    func requestPassphrase(for license: LCPAuthenticatedLicense, reason: LCPAuthenticationReason, completion: @escaping (String?) -> Void) {
        guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
            completion(nil)
            return
        }
        
        authenticationCallbacks[license.document.id] = completion
        
        let authenticationVC = LCPAuthenticationViewController(license: license, reason: reason)
        authenticationVC.delegate = self
      
        let navController = UINavigationController(rootViewController: authenticationVC)
        navController.modalPresentationStyle = .formSheet

        viewController.present(navController, animated: true)
    }

}


extension LCPLibraryService: LCPAuthenticationDelegate {
    
    func authenticate(_ license: LCPAuthenticatedLicense, with passphrase: String) {
        guard let callback = authenticationCallbacks.removeValue(forKey: license.document.id) else {
            return
        }
        callback(passphrase)
    }
    
    func didCancelAuthentication(of license: LCPAuthenticatedLicense) {
        guard let callback = authenticationCallbacks.removeValue(forKey: license.document.id) else {
            return
        }
        callback(nil)
    }
    
}

#endif
