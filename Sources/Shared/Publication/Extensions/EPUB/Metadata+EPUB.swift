//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

private let mediaOverlayKey = "mediaOverlay"

public extension Metadata {
    /// Media overlay CSS class names for this publication.
    var mediaOverlay: EPUBMediaOverlay? {
        try? otherMetadata[mediaOverlayKey]?.decode()
    }
}

package extension Metadata {
    /// Default EPUB layout of the publication, derived from `layout`.
    var epubLayout: EPUBLayout {
        EPUBLayout(layout)
    }

    /// Resolves the EPUB layout of the given `link`.
    ///
    /// A bitmap is always fixed-layout, as it cannot be reflowed. Otherwise,
    /// the per-resource `Properties.epubLayout` override wins over the
    /// publication default.
    func epubLayout(of link: Link) -> EPUBLayout {
        if link.mediaType?.isBitmap == true {
            return .fixed
        }

        return link.properties.epubLayout ?? epubLayout
    }
}
