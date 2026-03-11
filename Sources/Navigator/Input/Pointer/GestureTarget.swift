//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Metadata about an element interacted with a gesture.
public struct GestureTarget: Equatable {
    /// Frame of the element relative to the navigator's view.
    public let frame: CGRect

    /// Content of the element interacted with.
    public let content: Content?

    /// Raw content of the element interacted with.
    ///
    /// Can be used for advanced cases, for example it is the outer HTML of the
    /// element in an HTML resource.
    public let rawContent: RawContent?

    public init(frame: CGRect, content: Content? = nil, rawContent: RawContent? = nil) {
        self.frame = frame
        self.content = content
        self.rawContent = rawContent
    }

    /// Content extracted from an element.
    public enum Content: Equatable {
        /// Text element.
        ///
        /// If possible, provides the `word` that was touched by the gesture.
        case text(String, word: String?)

        /// Media element, e.g. a bitmap, SVG or audio file.
        ///
        /// The `Link` can be retrieved from the `Publication` since it might
        /// contain `alternate` in higher resolutions.
        case media(Link)
    }

    /// Raw content extracted from an element.
    public struct RawContent: Equatable {
        /// Media type which can be used to determine the format of the data.
        public let type: String

        /// String representation of the raw data.
        ///
        /// A bytes array should be base 64 encoded.
        public let data: String

        public init(type: String, data: String) {
            self.type = type
            self.data = data
        }
    }
}
