//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Variant of a resource rendered by the EPUB navigator, when a reading order
/// link has alternates (e.g. an XHTML page with a bitmap fallback).
public enum EPUBResourceVariant: Sendable, Hashable {
    /// Render the reading order links as authored, without walking alternates.
    case `default`

    /// Prefer the HTML/XHTML variant among a link and its alternates.
    case html

    /// Prefer a bitmap image variant among a link and its alternates.
    ///
    /// A rendered bitmap is always laid out as fixed-layout.
    case image
}
