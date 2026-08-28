//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Decides how an `EPUBSpreadView` should react to a navigation attempted in
/// its web view, e.g. when the user activates a link or when a script sets
/// `window.location`.
///
/// Cancelling the navigation and delegating internal links to the navigator
/// preserves the pagination, which would otherwise break when the web view
/// navigates by itself.
///
/// See https://github.com/readium/swift-toolkit/issues/125
struct EPUBNavigationPolicy {
    /// Decision for a navigation intercepted in the web view.
    enum Decision: Equatable {
        /// Lets the web view perform the navigation.
        case allow

        /// Cancels the navigation and delegates it as a jump to a link
        /// internal to the publication.
        case internalLink(href: String)

        /// Cancels the navigation and delegates it as a request to open an
        /// external URL, e.g. in the default web browser.
        case externalURL(URL)

        /// Cancels the navigation without delegating it, e.g. for `data:`
        /// URLs or unknown schemes which could be abused by a malicious
        /// publication.
        case block
    }

    /// Schemes of external URLs which are safe to delegate to the app, to be
    /// opened in the default web browser for example. Other schemes (e.g.
    /// `data:` or `javascript:`) are blocked as they could be abused by a
    /// malicious publication.
    private static let externalSchemes: Set<URLScheme> = [
        .http, .https,
        URLScheme(rawValue: "mailto"),
        URLScheme(rawValue: "tel"),
        URLScheme(rawValue: "sms"),
    ]

    /// Base URL from which the publication resources are served.
    private let publicationBaseURL: any AbsoluteURL

    /// URLs the spread view is expected to load in the web view by itself:
    /// the spread's resources and, for fixed layouts, the wrapper page.
    private let expectedLoadURLs: [AnyURL]

    init(publicationBaseURL: any AbsoluteURL, expectedLoadURLs: [AnyURL]) {
        self.publicationBaseURL = publicationBaseURL
        self.expectedLoadURLs = expectedLoadURLs
    }

    /// Returns the decision for a navigation to `url`.
    ///
    /// - Parameters:
    ///   - url: URL of the navigation request.
    ///   - targetFrameURL: URL currently loaded in the frame targeted by the
    ///     navigation, if known.
    ///   - targetsMainFrame: Whether the navigation targets the web view's
    ///     main frame.
    ///   - isLinkActivation: Whether the navigation was triggered by the user
    ///     activating a link, as opposed to a script or the spread view
    ///     itself.
    func decide(
        navigationTo url: URL?,
        targetFrameURL: URL?,
        targetsMainFrame: Bool,
        isLinkActivation: Bool
    ) -> Decision {
        guard let url = url else {
            return .allow
        }
        let destination = AnyURL(url: url)
        let scheme = url.scheme.map { URLScheme(rawValue: $0.lowercased()) }

        // Loads requested by the spread view itself, e.g. the spread's
        // resources or the fixed layout wrapper page.
        if !isLinkActivation, isExpectedLoad(destination) {
            return .allow
        }

        // Script-driven navigations in nested frames (e.g. an iframe embedded
        // in the content, or the initial `about:blank` load of the fixed
        // layout resource iframes) are allowed, unless they redirect one of
        // the spread's resource frames (fixed layout).
        if !targetsMainFrame, !isLinkActivation,
           targetFrameURL.map({ !isExpectedLoad(AnyURL(url: $0)) }) ?? true
        {
            return .allow
        }

        // Links to publication resources are delegated to the navigator, to
        // be performed as internal jumps preserving the pagination.
        if let href = publicationBaseURL.relativize(destination) {
            return .internalLink(href: href.string)
        }

        if let scheme = scheme, Self.externalSchemes.contains(scheme) {
            return .externalURL(url)
        }

        return .block
    }

    private func isExpectedLoad(_ url: AnyURL) -> Bool {
        expectedLoadURLs.contains { $0.isEquivalentTo(url) }
    }
}
