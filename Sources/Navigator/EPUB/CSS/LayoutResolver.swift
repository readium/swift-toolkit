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

    init(
        baseMinMargins: Double = 30.0,
        baseOptimalLineLength: Double = 640.0,
        baseMinLineLength: Double = 440.0,
        baseMaxLineLength: Double = 740.0
    ) {
        self.baseMinMargins = baseMinMargins
        self.baseOptimalLineLength = baseOptimalLineLength
        self.baseMinLineLength = baseMinLineLength
        self.baseMaxLineLength = baseMaxLineLength
    }

    /// Resolves the layout using `EPUBSettings`.
    func layout(
        settings: EPUBSettings,
        systemFontScale: Double = 1.0,
        viewportSize: CGSize,
        safeAreaInsets: UIEdgeInsets = .zero
    ) -> Layout {
        layout(
            scroll: settings.scroll,
            verticalText: settings.verticalText,
            columnCount: settings.columnCount == 0 ? nil : settings.columnCount,
            optimalLineLength: settings.lineLength,
            minimalLineLength: nil,
            maximalLineLength: nil,
            minMargins: settings.pageMargins,
            systemFontScale: systemFontScale,
            viewportSize: viewportSize,
            safeAreaInsets: safeAreaInsets
        )
    }

    /// Resolves the layout using individual layout parameters.
    func layout(
        scroll: Bool,
        verticalText: Bool,
        columnCount: Int?,
        optimalLineLength: Double,
        minimalLineLength: Double?,
        maximalLineLength: Double?,
        minMargins: Double,
        systemFontScale: Double = 1.0,
        viewportSize: CGSize,
        safeAreaInsets: UIEdgeInsets = .zero
    ) -> Layout {
        let optimalLineLength = baseOptimalLineLength * optimalLineLength * systemFontScale
        let minLineLength = minimalLineLength.map { baseMinLineLength * $0 * systemFontScale }
        let maxLineLength = maximalLineLength.map { baseMaxLineLength * $0 * systemFontScale }
        let minMargins = baseMinMargins * minMargins * systemFontScale

        let minMarginsWithInsets: Double = {
            if verticalText {
                return max(minMargins, max(safeAreaInsets.top, safeAreaInsets.bottom))
            } else {
                return max(minMargins, max(safeAreaInsets.left, safeAreaInsets.right))
            }
        }()

        if scroll {
            return scrolledLayout(
                viewportSize: verticalText ? viewportSize.height : viewportSize.width,
                minimalMargins: minMarginsWithInsets,
                maximalLineLength: maxLineLength
            )
        } else {
            return paginatedLayout(
                viewportWidth: viewportSize.width,
                requestedColCount: columnCount,
                minimalMargins: minMarginsWithInsets,
                optimalLineLength: optimalLineLength,
                maximalLineLength: maxLineLength,
                minimalLineLength: minLineLength
            )
        }
    }

    private func scrolledLayout(
        viewportSize: Double,
        minimalMargins: Double,
        maximalLineLength: Double?
    ) -> Layout {
        let minMargins = min(minimalMargins, viewportSize)
        let availableSize = viewportSize - (minMargins * 2)
        let maximalLineLength = maximalLineLength.map { max($0, minMargins * 2) }
        let lineLength = min(availableSize, maximalLineLength ?? availableSize)

        return Layout(
            colCount: 1,
            lineLength: lineLength
        )
    }

    private func paginatedLayout(
        viewportWidth: Double,
        requestedColCount: Int?,
        minimalMargins: Double,
        optimalLineLength: Double,
        maximalLineLength: Double?,
        minimalLineLength: Double?
    ) -> Layout {
        guard let requestedColCount, requestedColCount > 0 else {
            return paginatedLayoutAuto(
                minimalPageGutter: minimalMargins,
                optimalLineLength: optimalLineLength,
                viewportWidth: viewportWidth,
                maximalLineLength: maximalLineLength
            )
        }

        return paginatedLayoutNColumns(
            colCount: requestedColCount,
            minimalMargins: minimalMargins,
            viewportWidth: viewportWidth,
            minimalLineLength: minimalLineLength,
            maximalLineLength: maximalLineLength
        )
    }

    private func paginatedLayoutAuto(
        minimalPageGutter: Double,
        optimalLineLength: Double,
        viewportWidth: Double,
        maximalLineLength: Double?
    ) -> Layout {
        let optimalLineLength = min(optimalLineLength, viewportWidth)
        guard optimalLineLength > 0 else {
            return Layout(colCount: 1, lineLength: 0)
        }

        let minMarginWidthWithFloatingColCount =
            (minimalPageGutter * 2 * (viewportWidth / optimalLineLength)) / (1 + (minimalPageGutter * 2 / optimalLineLength))

        let floatingColCount = (viewportWidth - minMarginWidthWithFloatingColCount) / optimalLineLength
        let colCount = max(1, Int(floor(floatingColCount).rounded()))

        let minMarginWidth = minimalPageGutter * 2 * Double(colCount)
        let available = (viewportWidth - minMarginWidth) / Double(colCount)
        let lineLength = min(available, maximalLineLength ?? available)

        return Layout(colCount: colCount, lineLength: lineLength)
    }

    private func paginatedLayoutNColumns(
        colCount: Int,
        minimalMargins: Double,
        viewportWidth: Double,
        minimalLineLength: Double?,
        maximalLineLength: Double?
    ) -> Layout {
        let minPageGutter = min(minimalMargins, viewportWidth)
        let actualAvailableWidth = viewportWidth - (minPageGutter * 2 * Double(colCount))
        let minimalLineLength = minimalLineLength.map { min($0, actualAvailableWidth) }
        let maximalLineLength = maximalLineLength.map { max($0, minPageGutter * 2) }

        let lineLength = actualAvailableWidth / Double(colCount)

        if let minimalLineLength, lineLength < minimalLineLength, colCount > 1 {
            return paginatedLayoutNColumns(
                colCount: colCount - 1,
                minimalMargins: minPageGutter,
                viewportWidth: viewportWidth,
                minimalLineLength: minimalLineLength,
                maximalLineLength: maximalLineLength
            )
        } else if let maximalLineLength, lineLength > maximalLineLength {
            return Layout(
                colCount: colCount,
                lineLength: maximalLineLength
            )
        } else {
            return Layout(
                colCount: colCount,
                lineLength: lineLength
            )
        }
    }
}
