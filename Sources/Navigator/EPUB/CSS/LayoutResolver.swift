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
    func layout(
        settings: EPUBSettings,
        fontScale: Double,
        viewportSize: CGSize,
        insets: UIEdgeInsets = .zero
    ) -> Layout {
        layout(
            scroll: settings.scroll,
            verticalText: settings.verticalText,
            columnCount: settings.columnCount,
            optimalLineLength: settings.optimalLineLength,
            minimalLineLength: settings.minimalLineLength,
            maximalLineLength: settings.maximalLineLength,
            minMargins: settings.pageMargins,
            fontScale: fontScale,
            viewportSize: viewportSize,
            insets: insets
        )
    }

    /// Resolves the layout using individual layout parameters.
    ///
    /// - Parameters:
    ///   - fontScale: Font size factor the optimal, minimal and maximal line
    ///     lengths are multiplied by, so that a line holds about the same
    ///     number of characters at any font size. Must be above 0. The
    ///     margins don't follow it.
    ///   - insets: Insets the margins at the ends of the lines can't be
    ///     smaller than: left and right with horizontal text, top and bottom
    ///     with vertical text.
    func layout(
        scroll: Bool,
        verticalText: Bool,
        columnCount: Int?,
        optimalLineLength: Double,
        minimalLineLength: Double?,
        maximalLineLength: Double?,
        minMargins: Double,
        fontScale: Double,
        viewportSize: CGSize,
        insets: UIEdgeInsets = .zero
    ) -> Layout {
        // The parameters are factors, these lengths are in points.
        let optimalLength = baseOptimalLineLength * optimalLineLength * fontScale
        let minLength = minimalLineLength.map { baseMinLineLength * $0 * fontScale }
        let maxLength = maximalLineLength.map { baseMaxLineLength * $0 * fontScale }
        let insetsMargins = verticalText
            ? max(insets.top, insets.bottom)
            : max(insets.left, insets.right)
        let margins = max(baseMinMargins * minMargins, insetsMargins)

        if scroll {
            return scrolledLayout(
                viewportSize: verticalText ? viewportSize.height : viewportSize.width,
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
                minLength: minLength
            )
        }
    }

    // The lengths and margins of the functions below are in points.

    private func scrolledLayout(
        viewportSize: Double,
        margins: Double,
        maxLength: Double?
    ) -> Layout {
        let margins = min(margins, viewportSize)
        let availableSize = viewportSize - (margins * 2)
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
        minLength: Double?
    ) -> Layout {
        guard let requestedColCount, requestedColCount > 0 else {
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
