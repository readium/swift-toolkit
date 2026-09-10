//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// EPUB Link Properties Extension
/// https://readium.org/webpub-manifest/schema/extensions/epub/properties.schema.json
public extension Properties {
    /// Identifies content contained in the linked resource, that cannot be
    /// strictly identified using a media type.
    var contains: [String] {
        otherProperties["contains"]?.decode() ?? []
    }

    /// Hint about the nature of the layout for the linked resource, overriding
    /// the publication-wide `Metadata.layout`.
    ///
    /// In an EPUB, this is set from the `rendition:layout-*` properties of a
    /// spine `itemref`, allowing a publication to mix reflowable and
    /// fixed-layout resources.
    var epubLayout: EPUBLayout? {
        otherProperties["layout"]?.decode()
    }
}
