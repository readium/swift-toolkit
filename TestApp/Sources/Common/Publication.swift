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
            ($0.mediaType.map { DocumentTypes.main.supportsMediaType($0.string) } == true)
                || DocumentTypes.main.supportsFileExtension($0.url().pathExtension)
        }
    }
}

struct OPDSPublication: Hashable {
    let title: String?
    let authors: [Contributor]
    let images: [Link]
    let description: String?
    let baseURL: HTTPURL?
    
    init(from publication: Publication) {
        title = publication.metadata.title
        authors = publication.metadata.authors
        images = publication.images
        description = publication.metadata.description
        baseURL = publication.baseURL
    }
}
