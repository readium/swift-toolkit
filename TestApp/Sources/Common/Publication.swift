//
//  Copyright 2024 Readium Foundation. All rights reserved.
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
            DocumentTypes.main.supportsMediaType($0.type)
                || DocumentTypes.main.supportsFileExtension(try? $0.url().url.pathExtension)
        }
    }
}
