//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Reading order rendered by the EPUB navigator, after picking the preferred
/// variant of each resource among its alternates.
///
/// Only one level of alternates is considered. SMIL, audio, video and other
/// media types are never rendered. A rendered bitmap is always laid out as
/// fixed-layout.
///
/// Use the alternates-aware `index(of:)` and `resolve(_:)` to look up a
/// resource, so that hrefs referencing another variant of a rendered link are
/// still found.
struct EPUBReadingOrder {
    
    /// Links rendered by the navigator.
    let links: [Link]

    /// - Parameters:
    ///   - readingOrder: Links to render, either the publication's reading
    ///     order or a custom one.
    ///   - preferredVariant: Variant to render among each link and its
    ///     alternates.
    init(readingOrder: [Link], preferredVariant: EPUBResourceVariant) {
        links = readingOrder.map { renderedLink(for: $0, preferredVariant: preferredVariant) }
    }

    /// Finds the index of the rendered link matching `href`, looking first
    /// at the rendered links, then at one level of their alternates.
    ///
    /// - Parameters:
    ///   - href: HREF of the resource to find, which can reference any
    ///     variant of a rendered link.
    func index<T: URLConvertible>(of href: T) -> Int? {
        links.firstIndexWithHREF(href)
            ?? links.firstIndex { $0.alternates.firstIndexWithHREF(href) != nil }
    }

    /// Resolves `locator` against the rendered links.
    ///
    /// The returned locator targets the rendered link. When the locator
    /// references another variant, its fragments and other locations (e.g.
    /// `cssSelector`) are dropped as they are not meaningful anymore.
    ///
    /// - Parameters:
    ///   - locator: Locator to resolve, which can reference any variant of a
    ///     rendered link.
    func resolve(_ locator: Locator) -> (index: Int, locator: Locator)? {
        guard let index = index(of: locator.href) else {
            return nil
        }

        let link = links[index]
        let href = link.url()
        guard !href.isEquivalentTo(locator.href) else {
            return (index, locator)
        }

        var resolved = locator.copy(href: href, mediaType: link.mediaType)
        resolved.locations.fragments = []
        resolved.locations.otherLocations = [:]
        return (index, resolved)
    }
}

/// Returns the link to render for `main`, according to the
/// `preferredVariant`.
///
/// - Parameters:
///   - main: Reading order link, with its alternates.
///   - preferredVariant: Variant to render among `main` and its alternates.
private func renderedLink(for main: Link, preferredVariant: EPUBResourceVariant) -> Link {
    // Candidates are handled by index, as duplicate links are possible.
    let candidates = [main] + main.alternates
    let pick = preferredIndex(in: candidates, for: preferredVariant) ?? 0

    var link = (pick == 0) ? main : promote(candidates: candidates, at: pick)

    if link.mediaType?.isBitmap == true {
        link.properties.epubLayout = .fixed
    }

    return link
}

/// Returns the index of the first candidate matching `preferredVariant`.
///
/// - Parameters:
///   - candidates: Main link followed by its alternates.
///   - preferredVariant: Variant to find among `candidates`.
private func preferredIndex(in candidates: [Link], for preferredVariant: EPUBResourceVariant) -> Int? {
    switch preferredVariant {
    case .default:
        return 0
    case .html:
        return candidates.firstIndex { $0.mediaType?.isHTML == true }
    case .image:
        return candidates.firstIndex { $0.mediaType?.isBitmap == true }
    }
}

/// Promotes the alternate at `index` as the main link.
///
/// The link describes the alternate's resource, while the title, relations and
/// properties (e.g. the page spread) are transferred from the main link. The
/// former main link becomes the first alternate.
///
/// - Parameters:
///   - candidates: Main link followed by its alternates.
///   - index: Index of the candidate to promote, greater than 0.
private func promote(candidates: [Link], at index: Int) -> Link {
    let main = candidates[0]
    let pick = candidates[index]

    var link = pick
    link.title = main.title
    link.rels = main.rels
    link.properties = main.properties

    var demoted = main
    demoted.alternates = []
    var alternates = main.alternates
    alternates.remove(at: index - 1)
    link.alternates = [demoted] + alternates

    return link
}
