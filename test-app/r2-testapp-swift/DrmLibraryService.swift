//
//  Created by Mickaël Menu on 01.02.19.
//  Copyright © 2019 Readium. All rights reserved.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

protocol DrmLibraryService {
    
    var brand: Drm.Brand { get }
    
    /// Returns whether this DRM can fulfill the given file into a protected publication.
    func canFulfill(_ file: URL) -> Bool
    
    /// Fulfills the given file to the fully protected publication.
    func fulfill(_ file: URL, completion: @escaping (CancellableResult<(URL, URLSessionDownloadTask?)>) -> Void)
    
    /// Fills the DRM context of the given protected publication.
    func loadPublication(at publication: URL, drm: Drm, completion: @escaping (CancellableResult<Drm>) -> Void)
    
    /// Handles the deletion of DRM-related data for this publication, if there's any.
    func removePublication(at publication: URL)
    
}
