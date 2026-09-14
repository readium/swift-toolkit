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
        layout == .fixed ? .fixed : .reflowable
    }

    /// Resolves the EPUB layout of the given `link`.
    ///
    /// The per-resource `Properties.epubLayout` override wins over the
    /// publication default.
    func epubLayout(of link: Link) -> EPUBLayout {
        link.properties.epubLayout ?? epubLayout
    }
}
