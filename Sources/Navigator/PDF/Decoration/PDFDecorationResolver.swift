//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import PDFKit
import ReadiumShared

/// Resolves the geometry of a `Decoration` on a PDF page.
enum PDFDecorationResolver {
    /// Resolves the line boxes for `locator` on `page`, in PDF user space
    /// (origin at the bottom-left corner).
    ///
    /// The resolution strategy is, in order of priority:
    /// 1. Explicit rect fragments (`highlight=`, `viewrect=`) in
    ///    `locations.fragments`, rendered directly with no text search.
    /// 2. A text search of `text.highlight`, scoped to the page.
    /// 3. The whole page, **only** when the locator intentionally has no
    ///    `text.highlight` and no rect fragments — a deliberate page-level
    ///    decoration.
    ///
    /// Returns `nil` when the locator is unresolvable, e.g. its
    /// `text.highlight` is not found on the page (scanned PDF without a text
    /// layer, or stale locator). A failed search must never degrade into a
    /// full-page highlight.
    @MainActor
    static func resolveRects(for locator: Locator, on page: PDFPage) -> [CGRect]? {
        let pageBounds = page.bounds(for: .cropBox)

        let rectFragments = PDFRectFragment.parse(fragments: locator.locations.fragments)
        if !rectFragments.isEmpty {
            return rectFragments.map { $0.rect(inPageBounds: pageBounds) }
        }

        if let query = locator.text.highlight, !query.isEmpty {
            guard
                let pageText = page.string,
                let range = PDFTextMatcher.findRange(
                    of: query,
                    in: pageText,
                    before: locator.text.before,
                    after: locator.text.after
                ),
                let selection = page.selection(for: range)
            else {
                return nil
            }
            let rects = selection.selectionsByLine()
                .map { $0.bounds(for: page) }
                .filter { !$0.isEmpty }
            return rects.isEmpty ? nil : rects
        }

        return [pageBounds]
    }
}
