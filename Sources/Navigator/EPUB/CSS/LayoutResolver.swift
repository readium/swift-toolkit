//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreGraphics
import Foundation
import UIKit

/// Resolves column count and line length constraints for reflowable content.
final class LayoutResolver {
    /// Result of layout resolution for reflowable content.
    struct Layout: Equatable, Sendable {
        /// Number of columns to display.
        let colCount: Int
        /// Line length in points.
        let lineLength: Double
    }

    private let baseMinMargins: Double
    private let baseOptimalLineLength: Double
    private let baseMinLineLength: Double
    private let baseMaxLineLength: Double

    /// The default line lengths are the ones of the Readium TypeScript
    /// toolkit: the width of 65 (optimal), 40 (minimal) and 80 (maximal)
    /// "0" characters at 16px in Iowan Old Style. They are the lengths at a
    /// 100% font size, see the `fontScale` parameter of `layout()`.
    init(
        baseMinMargins: Double = 30.0,
        baseOptimalLineLength: Double = 578.0,
        baseMinLineLength: Double = 356.0,
        baseMaxLineLength: Double = 712.0
    ) {
        self.baseMinMargins = baseMinMargins
        self.baseOptimalLineLength = baseOptimalLineLength
        self.baseMinLineLength = baseMinLineLength
        self.baseMaxLineLength = baseMaxLineLength
    }

    /// Resolves the layout using `EPUBSettings`.
    ///
    /// - Parameters:
    ///   - fontScale: Font size factor the optimal, minimal and maximal line
    ///     lengths are multiplied by, usually the `fontSize` setting. Must be
    ///     above 0. The margins don't follow it.
    ///   - insets: Insets the margins at the ends of the lines can't be
    ///     smaller than: left and right with horizontal text, top and bottom
    ///     with vertical text.
    ///   - hingeWidth: Width of the vertical hinge splitting the viewport in
    ///     two equal sides, on a foldable device. See
    ///     `verticalHingeWidth(divisions:in:tolerance:)`.
    func layout(
        settings: EPUBSettings,
        fontScale: Double,
        viewportSize: CGSize,
        insets: UIEdgeInsets = .zero,
        hingeWidth: Double? = nil
    ) -> Layout {
        layout(
            scroll: settings.scroll,
            verticalText: settings.verticalText,
            columnCount: settings.columnCount,
            optimalLineLength: settings.optimalLineLength,
            minimalLineLength: settings.minimalLineLength,
            maximalLineLength: settings.maximalLineLength,
            pageMargins: settings.pageMargins,
            fontScale: fontScale,
            viewportSize: viewportSize,
            insets: insets,
            hingeWidth: hingeWidth
        )
    }

    /// Resolves the layout using individual layout parameters.
    ///
    /// - Parameters:
    ///   - pageMargins: Factor the base minimal margins are multiplied by,
    ///     usually the `pageMargins` setting.
    ///   - fontScale: Font size factor the optimal, minimal and maximal line
    ///     lengths are multiplied by, so that a line holds about the same
    ///     number of characters at any font size. Must be above 0. The
    ///     margins don't follow it.
    ///   - insets: Insets the margins at the ends of the lines can't be
    ///     smaller than: left and right with horizontal text, top and bottom
    ///     with vertical text.
    ///   - hingeWidth: Width of the vertical hinge splitting the viewport in
    ///     two equal sides, on a foldable device. See
    ///     `verticalHingeWidth(divisions:in:tolerance:)`.
    ///     In paginated mode with horizontal text, when the number of columns
    ///     is automatic, each side gets its own column and the margins are at
    ///     least half of the hinge, so that no text is on the hinge.
    func layout(
        scroll: Bool,
        verticalText: Bool,
        columnCount: Int?,
        optimalLineLength: Double,
        minimalLineLength: Double?,
        maximalLineLength: Double?,
        pageMargins: Double,
        fontScale: Double,
        viewportSize: CGSize,
        insets: UIEdgeInsets = .zero,
        hingeWidth: Double? = nil
    ) -> Layout {
        // The parameters are factors, these lengths are in points.
        let optimalLength = baseOptimalLineLength * optimalLineLength * fontScale
        let minLength = minimalLineLength.map { baseMinLineLength * $0 * fontScale }
        let maxLength = maximalLineLength.map { baseMaxLineLength * $0 * fontScale }
        let insetsMargins = verticalText
            ? max(insets.top, insets.bottom)
            : max(insets.left, insets.right)
        let margins = max(baseMinMargins * pageMargins, insetsMargins)

        if scroll {
            return scrolledLayout(
                viewportLength: verticalText ? viewportSize.height : viewportSize.width,
                margins: margins,
                maxLength: maxLength
            )
        } else {
            return paginatedLayout(
                viewportWidth: viewportSize.width,
                requestedColCount: columnCount,
                margins: margins,
                optimalLength: optimalLength,
                maxLength: maxLength,
                minLength: minLength,
                // Vertical text is always scrolled, and its columns are not
                // laid out side by side.
                hingeWidth: verticalText ? nil : hingeWidth
            )
        }
    }

    // The lengths and margins of the functions below are in points.

    private func scrolledLayout(
        viewportLength: Double,
        margins: Double,
        maxLength: Double?
    ) -> Layout {
        let margins = min(margins, viewportLength)
        let availableSize = viewportLength - (margins * 2)
        let maxLength = maxLength.map { max($0, margins * 2) }
        let lineLength = min(availableSize, maxLength ?? availableSize)

        return Layout(
            colCount: 1,
            lineLength: lineLength
        )
    }

    private func paginatedLayout(
        viewportWidth: Double,
        requestedColCount: Int?,
        margins: Double,
        optimalLength: Double,
        maxLength: Double?,
        minLength: Double?,
        hingeWidth: Double?
    ) -> Layout {
        guard let requestedColCount, requestedColCount > 0 else {
            if
                let hingeWidth,
                let layout = paginatedLayoutAroundHinge(
                    hingeWidth: hingeWidth,
                    margins: margins,
                    viewportWidth: viewportWidth,
                    maxLength: maxLength
                )
            {
                return layout
            }

            return paginatedLayoutAuto(
                margins: margins,
                optimalLength: optimalLength,
                viewportWidth: viewportWidth,
                maxLength: maxLength
            )
        }

        return paginatedLayoutNColumns(
            colCount: requestedColCount,
            margins: margins,
            viewportWidth: viewportWidth,
            minLength: minLength,
            maxLength: maxLength
        )
    }

    private func paginatedLayoutAuto(
        margins: Double,
        optimalLength: Double,
        viewportWidth: Double,
        maxLength: Double?
    ) -> Layout {
        let optimalLength = min(optimalLength, viewportWidth)
        guard optimalLength > 0 else {
            return Layout(colCount: 1, lineLength: 0)
        }

        let minMarginWidthWithFloatingColCount =
            (margins * 2 * (viewportWidth / optimalLength)) / (1 + (margins * 2 / optimalLength))

        let floatingColCount = (viewportWidth - minMarginWidthWithFloatingColCount) / optimalLength
        let colCount = max(1, Int(floor(floatingColCount)))

        let minMarginWidth = margins * 2 * Double(colCount)
        let available = (viewportWidth - minMarginWidth) / Double(colCount)
        let lineLength = min(available, maxLength ?? available)

        return Layout(colCount: colCount, lineLength: lineLength)
    }

    /// Lays out one column on each side of a vertical hinge. The gap between
    /// them is centered on the hinge, as the lines are centered in their
    /// columns.
    ///
    /// There is only one column on each side, even if a side could hold
    /// more, so that each side is a page. As every column has the same
    /// margins, more columns would also have the margins of the hinge away
    /// from it.
    ///
    /// Returns `nil` when a side, outside of the hinge, is narrower than the
    /// base minimal line length. Like in auto mode without a hinge, the
    /// minimal line length setting doesn't apply.
    private func paginatedLayoutAroundHinge(
        hingeWidth: Double,
        margins: Double,
        viewportWidth: Double,
        maxLength: Double?
    ) -> Layout? {
        let halfHinge = max(hingeWidth, 0) / 2
        let sideWidth = viewportWidth / 2
        // This minimum doesn't follow the font size or the margins: it only
        // rules out sides too narrow to be pages, such as with a small
        // window. A larger font or margins shorten the lines as they do on
        // the screen of a phone.
        guard sideWidth - halfHinge >= baseMinLineLength else {
            return nil
        }

        let available = sideWidth - max(margins, halfHinge) * 2
        let lineLength = min(available, maxLength ?? available)
        return Layout(colCount: 2, lineLength: lineLength)
    }

    private func paginatedLayoutNColumns(
        colCount: Int,
        margins: Double,
        viewportWidth: Double,
        minLength: Double?,
        maxLength: Double?
    ) -> Layout {
        let margins = min(margins, viewportWidth)
        let actualAvailableWidth = viewportWidth - (margins * 2 * Double(colCount))
        let minLength = minLength.map { min($0, actualAvailableWidth) }
        let maxLength = maxLength.map { max($0, margins * 2) }

        let lineLength = actualAvailableWidth / Double(colCount)

        if let minLength, lineLength < minLength, colCount > 1 {
            return paginatedLayoutNColumns(
                colCount: colCount - 1,
                margins: margins,
                viewportWidth: viewportWidth,
                minLength: minLength,
                maxLength: maxLength
            )
        } else if let maxLength, lineLength > maxLength {
            return Layout(
                colCount: colCount,
                lineLength: maxLength
            )
        } else {
            return Layout(
                colCount: colCount,
                lineLength: lineLength
            )
        }
    }
}

extension LayoutResolver {
    /// Returns the width of the hinge splitting the view in two equal sides,
    /// on a foldable device, from the frames of the division regions of the
    /// view (`UIView.ReservedRegion.Kind.division`).
    ///
    /// Only a division covering the full height of the view and centered in
    /// it, within `tolerance` points, is a hinge between two sides: a
    /// horizontal division or one off the center (for example, when the app
    /// shares the screen with another one) is ignored. As the frames of the
    /// regions can be out of sync with the bounds during a transition, this
    /// also ignores a frame which doesn't match the bounds.
    ///
    /// - Parameters:
    ///   - divisions: Frames of the division regions, including their
    ///     margins, in the coordinate space of the view.
    ///   - bounds: Bounds of the view.
    static func verticalHingeWidth(
        divisions: [CGRect],
        in bounds: CGRect,
        tolerance: Double = 2
    ) -> Double? {
        guard !bounds.isEmpty else {
            return nil
        }

        return divisions
            .first { division in
                division.width < bounds.width / 2
                    && division.minY <= bounds.minY + tolerance
                    && division.maxY >= bounds.maxY - tolerance
                    && abs(division.midX - bounds.midX) <= tolerance
            }
            .map { Double($0.width) }
    }
}
