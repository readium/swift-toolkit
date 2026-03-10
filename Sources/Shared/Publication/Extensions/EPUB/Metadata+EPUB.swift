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
        EPUBMediaOverlay(json: otherMetadata[mediaOverlayKey])
    }
}
