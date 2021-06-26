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
    let suggestedFilename: String
}


protocol DRMLibraryService {
    
    /// Returns the `ContentProtection` which will be provided to the `Streamer`, to unlock
    /// publications.
    var contentProtection: ContentProtection? { get }
    
    /// Returns whether this DRM can fulfill the given file into a protected publication.
    func canFulfill(_ file: URL) -> Bool
    
    /// Fulfills the given file to the fully protected publication.
    func fulfill(_ file: URL) -> Deferred<DRMFulfilledPublication, Error>
    
}
