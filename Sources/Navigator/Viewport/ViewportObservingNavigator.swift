//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared

/// A navigator that exposes information about its currently visible portion
/// of the publication.
public protocol ViewportObservingNavigator: VisualNavigator {
    /// Information about the visible portion of the publication, when rendered.
    /// `nil` while the navigator is still initializing.
    var viewport: NavigatorViewport? { get }
}

/// Delegate for receiving viewport updates from any
/// ``ViewportObservingNavigator``.
@MainActor public protocol ViewportObservingNavigatorDelegate: AnyObject {
    /// Called when the viewport is updated.
    func navigator(_ navigator: any ViewportObservingNavigator, viewportDidChange viewport: NavigatorViewport?)
}

public extension ViewportObservingNavigatorDelegate {
    func navigator(_ navigator: any ViewportObservingNavigator, viewportDidChange viewport: NavigatorViewport?) {}
}

/// Information about the visible portion of a publication.
public struct NavigatorViewport: Equatable {
    /// Visible reading order resources, in reading order.
    public var resources: [Resource]

    /// Range of visible total progression in the publication (0.0–1.0).
    ///
    /// The lower bound is the progression at the top of the visible area, while
    /// the upper bound is at the bottom.
    public var progression: ClosedRange<Double>

    /// Range of visible positions in the publication's position list.
    /// `nil` if positions are not available for this publication.
    public var positions: ClosedRange<Int>?

    public init(
        resources: [Resource],
        progression: ClosedRange<Double>,
        positions: ClosedRange<Int>? = nil
    ) {
        self.resources = resources
        self.progression = progression
        self.positions = positions
    }

    /// A visible reading order resource inside the viewport.
    public struct Resource: Equatable {
        /// HREF of the reading order resource.
        public var href: AnyURL

        /// Range of visible scroll progression (0.0–1.0) inside the resource.
        ///
        /// For fixed-layout or page-based content where the resource is fully
        /// visible, this is `0.0...1.0`.
        public var progression: ClosedRange<Double>

        public init(href: AnyURL, progression: ClosedRange<Double>) {
            self.href = href
            self.progression = progression
        }
    }

    // MARK: - Deprecated

    /// Visible reading order resource HREFs.
    @available(*, deprecated, message: "Use resources instead")
    public var readingOrder: [AnyURL] {
        resources.map(\.href)
    }

    /// Range of visible scroll progressions for each visible reading order resource.
    @available(*, deprecated, message: "Use resources instead")
    public var progressions: [AnyURL: ClosedRange<Double>] {
        Dictionary(resources.map { ($0.href, $0.progression) }, uniquingKeysWith: { $1 })
    }
}
