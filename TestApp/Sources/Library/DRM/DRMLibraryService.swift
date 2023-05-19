//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
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
    func fulfill(_ file: URL) async throws -> DRMFulfilledPublication?
}
