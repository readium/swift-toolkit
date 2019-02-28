//
//  DRMViewModel.swift
//  r2-testapp-swift (carthage)
//
//  Created by Mickaël Menu on 19.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import R2Shared

/// Used to display a DRM license's informations
/// Should be subclassed for specific DRM.
class DRMViewModel: NSObject {

    /// Class cluster factory.
    /// Use this instead of regular constructors to create the right DRM view model.
    static func make(drm: DRM, presentingViewController: UIViewController) -> DRMViewModel {
        #if LCP
        if case .lcp = drm.brand {
            return LCPViewModel(drm: drm, presentingViewController: presentingViewController)
        }
        #endif
        
        return DRMViewModel(drm: drm, presentingViewController: presentingViewController)
    }
    
    let drm: DRM
    
    /// Host view controller to be used to present any dialog.
    weak var presentingViewController: UIViewController?

    init(drm: DRM, presentingViewController: UIViewController) {
        self.drm = drm
        self.presentingViewController = presentingViewController
    }
    
    var license: DRMLicense? {
        return drm.license
    }
    
    var type: String {
        return drm.brand.rawValue
    }
    
    var state: String? {
        return nil
    }
    
    var provider: String? {
        return nil
    }
    
    var issued: Date? {
        return nil
    }
    
    var updated: Date? {
        return nil
    }
    
    var start: Date? {
        return nil
    }
    
    var end: Date? {
        return nil
    }
    
    var copiesLeft: String {
        return "unlimited"
    }
    
    var printsLeft: String {
        return "unlimited"
    }
    
    var canRenewLoan: Bool {
        return false
    }
    
    func renewLoan(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
    
    var canReturnPublication: Bool {
        return false
    }
    
    func returnPublication(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

}
