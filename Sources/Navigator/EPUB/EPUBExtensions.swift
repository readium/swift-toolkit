//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared

extension Metadata {
    var epubLayout: EPUBLayout {
        layout == .fixed ? .fixed : .reflowable
    }
}

extension Locator {
    /// Returns a copy of this locator anchored to the content (CSS selector
    /// and text context) of the given `anchor` locator, if they point to the
    /// same resource.
    ///
    /// This is used to restore the reading position by re-anchoring to the
    /// actual content instead of relying on a progression percentage, which
    /// drifts when the content is reflowed (e.g. after changing the font
    /// size).
    /// See https://github.com/readium/swift-toolkit/issues/645
    ///
    /// This handles the case where the resources are reloaded (e.g. after a
    /// pagination-invalidating preference change), the anchor surviving the
    /// reload as a serialized CSS selector and text snippet. The counterpart
    /// for in-place reflows (e.g. a font size change committed with
    /// `readium.setCSSProperties()`) is `captureReadingPositionAnchor()` in
    /// `Scripts/src/utils.js`, which uses a live DOM Range instead because the
    /// document survives. Keep both strategies in sync.
    func anchored(to anchor: Locator) -> Locator {
        guard anchor.href.removingFragment().isEquivalentTo(href.removingFragment()) else {
            return self
        }
        return copy(
            locations: { $0.cssSelector = anchor.locations.cssSelector },
            text: {
                $0 = anchor.text
                // The anchor's highlight is the full text content of an
                // element, which can be a whole paragraph. Truncate it, as
                // this locator is exposed through `currentLocation` which
                // apps may persist, and a short prefix is enough to anchor
                // back to the element.
                $0.highlight = $0.highlight.map { String($0.prefix(maxAnchorHighlightLength)) }
            }
        )
    }
}

/// Maximum length of the text highlight kept when anchoring a locator to the
/// content with `Locator.anchored(to:)`.
private let maxAnchorHighlightLength = 200
