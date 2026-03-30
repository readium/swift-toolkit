//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// EPUB Link Properties Extension
/// https://readium.org/webpub-manifest/schema/extensions/epub/properties.schema.json
public extension Properties {
    /// Identifies content contained in the linked resource, that cannot be strictly identified
    /// using a media type.
    var contains: [String] {
        otherProperties["contains"]?.decode() ?? []
    }
}
