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
import R2Shared

/// Used to display a DRM license's informations
/// Should be subclassed for specific DRM.
class DRMViewModel {

    /// Class cluster factory.
    /// Use this instead of regular constructors to create the right DRM view model.
    static func make(drm: DRM) -> DRMViewModel {
        #if LCP
        if case .lcp = drm.brand {
            return LCPViewModel(drm: drm)
        }
        #endif
        
        return DRMViewModel(drm: drm)
    }
    
    let drm: DRM

    init(drm: DRM) {
        self.drm = drm
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
