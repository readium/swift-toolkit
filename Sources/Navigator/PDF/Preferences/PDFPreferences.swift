//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Preferences for the `PDFNavigatorViewController`.
public struct PDFPreferences: ConfigurablePreferences, Sendable {
    public static let empty: PDFPreferences = .init()

    /// Background color behind the document pages.
    public var backgroundColor: Color?

    /// Method for fitting the pages within the viewport.
    public var fit: Fit?

    /// Indicates whether the first page should be displayed alone instead of
    /// alongside the second page.
    ///
    /// This only applies if spreads are enabled.
    public var offsetFirstPage: Bool?

    /// Spacing between pages in points.
    ///
    /// Accepted range: `0.0...`, negative values are replaced with `0.0`.
    /// Suggested range: `0.0...200.0`, with a step of `4.0`.
    public var pageSpacing: Double?

    /// Direction of the horizontal progression across pages.
    public var readingProgression: ReadingProgression?

    /// Indicates if pages should be handled using scrolling instead of
    /// pagination.
    public var scroll: Bool?

    /// Indicates the axis along which pages should be laid out in scroll mode.
    public var scrollAxis: Axis?

    /// Indicates if the publication should be rendered with a synthetic spread
    /// (dual-page).
    public var spread: Spread?

    /// Indicates whether the scrollbar should be visible while scrolling.
    public var visibleScrollbar: Bool?

    public init(
        backgroundColor: Color? = nil,
        fit: Fit? = nil,
        offsetFirstPage: Bool? = nil,
        pageSpacing: Double? = nil,
        readingProgression: ReadingProgression? = nil,
        scroll: Bool? = nil,
        scrollAxis: Axis? = nil,
        spread: Spread? = nil,
        visibleScrollbar: Bool? = nil
    ) {
        self.backgroundColor = backgroundColor
        self.fit = fit
        self.offsetFirstPage = offsetFirstPage
        self.pageSpacing = pageSpacing.map { max($0, 0) }
        self.readingProgression = readingProgression
        self.scroll = scroll
        self.scrollAxis = scrollAxis
        self.spread = spread
        self.visibleScrollbar = visibleScrollbar
    }
}

public extension PDFPreferences {
    @available(*, unavailable, message: "Store the publication-specific settings in your own settings model, see the migration guide")
    func filterSharedPreferences() -> PDFPreferences {
        fatalError()
    }

    @available(*, unavailable, message: "Store the publication-specific settings in your own settings model, see the migration guide")
    func filterPublicationPreferences() -> PDFPreferences {
        fatalError()
    }
}

/// Decodes the `PDFPreferences` persisted with Readium 3.x, to migrate them
/// to your own settings model.
///
/// This is a snapshot of the 3.x `PDFPreferences`, with the values as they
/// were saved. The decoding is lenient: an invalid value drops only its
/// preference.
///
/// It will be removed in a future major version.
public struct LegacyPDFPreferences: Decodable, Hashable, Sendable {
    /// Background color behind the document pages, as a packed RGB integer.
    public let backgroundColor: Int?
    /// Method for fitting the pages within the viewport.
    public let fit: Fit?
    /// Indicates whether the first page should be displayed alone instead of
    /// alongside the second page.
    public let offsetFirstPage: Bool?
    /// Spacing between pages in points.
    public let pageSpacing: Double?
    /// Direction of the horizontal progression across pages.
    public let readingProgression: ReadingProgression?
    /// Indicates if pages should be handled using scrolling instead of
    /// pagination.
    public let scroll: Bool?
    /// Indicates the axis along which pages should be laid out in scroll mode.
    public let scrollAxis: Axis?
    /// Indicates if the publication should be rendered with a synthetic spread
    /// (dual-page).
    public let spread: Spread?
    /// Indicates whether the scrollbar should be visible while scrolling.
    public let visibleScrollbar: Bool?

    public enum Axis: String, Decodable, Hashable, Sendable {
        case horizontal
        case vertical
    }

    public enum Fit: String, Decodable, Hashable, Sendable {
        case auto
        case page
        case width
    }

    public enum ReadingProgression: String, Decodable, Hashable, Sendable {
        case ltr
        case rtl
    }

    public enum Spread: String, Decodable, Hashable, Sendable {
        case auto
        case never
        case always
    }
}

public extension LegacyPDFPreferences {
    private enum CodingKeys: String, CodingKey {
        case backgroundColor
        case fit
        case offsetFirstPage
        case pageSpacing
        case readingProgression
        case scroll
        case scrollAxis
        case spread
        case visibleScrollbar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        backgroundColor = container.decodeLeniently(Int.self, forKey: .backgroundColor)
        fit = container.decodeLeniently(Fit.self, forKey: .fit)
        offsetFirstPage = container.decodeLeniently(Bool.self, forKey: .offsetFirstPage)
        pageSpacing = container.decodeLeniently(Double.self, forKey: .pageSpacing)
        readingProgression = container.decodeLeniently(ReadingProgression.self, forKey: .readingProgression)
        scroll = container.decodeLeniently(Bool.self, forKey: .scroll)
        scrollAxis = container.decodeLeniently(Axis.self, forKey: .scrollAxis)
        spread = container.decodeLeniently(Spread.self, forKey: .spread)
        visibleScrollbar = container.decodeLeniently(Bool.self, forKey: .visibleScrollbar)
    }
}
