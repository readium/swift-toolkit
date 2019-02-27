//
//  DRMLibraryService.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 01.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared


struct DRMFulfilledPublication {
    let localURL: URL
    let downloadTask: URLSessionDownloadTask?
    let suggestedFilename: String
}


protocol DRMLibraryService {
    
    var brand: DRM.Brand { get }
    
    /// Returns whether this DRM can fulfill the given file into a protected publication.
    func canFulfill(_ file: URL) -> Bool
    
    /// Fulfills the given file to the fully protected publication.
    func fulfill(_ file: URL, completion: @escaping (CancellableResult<DRMFulfilledPublication>) -> Void)
    
    /// Fills the DRM context of the given protected publication.
    func loadPublication(at publication: URL, drm: DRM, completion: @escaping (CancellableResult<DRM?>) -> Void)

}
