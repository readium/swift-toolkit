//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreServices
import Foundation
import ReadiumShared

extension Publication {
    /// Finds all the downloadable links for this publication.
    var downloadLinks: [Link] {
        links.filter {
            ($0.mediaType.map { DocumentTypes.main.supportsMediaType($0.string) } == true)
                || DocumentTypes.main.supportsFileExtension($0.url().pathExtension?.rawValue)
        }
    }
}
