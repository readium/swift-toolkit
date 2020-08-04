//
//  Presentation+EPUB.swift
//  r2-streamer-swift
//
//  Created by Mickaël on 24/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

extension Presentation.Orientation {
    
    /// Creates from an EPUB rendition:orientation property.
    public init(epub: String, fallback: Presentation.Orientation? = nil) {
        switch epub {
        case "landscape":
            self = .landscape
        case "portrait":
            self = .portrait
        case "auto":
            self = .auto
        default:
            self = fallback ?? .auto
        }
    }

}

extension Presentation.Overflow {
    
    /// Creates from an EPUB rendition:flow property.
    public init(epub: String, fallback: Presentation.Overflow? = nil) {
        switch epub {
        case "auto":
            self = .auto
        case "paginated":
            self = .paginated
        case "scrolled-doc", "scrolled-continuous":
            self = .scrolled
        default:
            self = fallback ?? .auto
        }
    }
    
}

extension Presentation.Spread {

    /// Creates from an EPUB rendition:spread property.
    public init(epub: String, fallback: Presentation.Spread? = nil) {
        switch epub {
        case "none":
            self = .none
        case "auto":
            self = .auto
        case "landscape":
            self = .landscape
            // `portrait` is deprecated and should fallback to `both`.
        // See. https://readium.org/architecture/streamer/parser/metadata#epub-3x-11
        case "both", "portrait":
            self = .both
        default:
            self = fallback ?? .auto
        }
    }
    
}

extension EPUBLayout {
    
    /// Creates from an EPUB rendition:layout property.
    public init(epub: String, fallback: EPUBLayout? = nil) {
        switch epub {
        case "reflowable":
            self = .reflowable
        case "pre-paginated":
            self = .fixed
        default:
            self = fallback ?? .reflowable
        }
    }
    
}
