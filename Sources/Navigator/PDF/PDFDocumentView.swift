//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import PDFKit

protocol PDFDocumentViewDelegate: AnyObject {
    func pdfDocumentViewContentInset(_ pdfDocumentView: PDFDocumentView) -> UIEdgeInsets?
}

public final class PDFDocumentView: PDFView {
    var editingActions: EditingActionsController
    private weak var documentViewDelegate: PDFDocumentViewDelegate?

    init(
        frame: CGRect,
        editingActions: EditingActionsController,
        documentViewDelegate: PDFDocumentViewDelegate
    ) {
        self.editingActions = editingActions
        self.documentViewDelegate = documentViewDelegate

        super.init(frame: frame)

        // For a reader, the default inset adjustement is not appropriate. Usually, we want to
        // display any navigation bar above the content (to avoid it jumping when toggling the
        // navigation bars), while still making sure that the content is entirely visible despite
        // the screen notches.
        // Thefore, we will handle the adjustement manually by only taking the notch area into
        // account.
        firstScrollView?.contentInsetAdjustmentBehavior = .never
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateContentInset()
    }

    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateContentInset()
    }

    private func updateContentInset() {
        let insets = contentInset
        firstScrollView?.contentInset.top = insets.top
        firstScrollView?.contentInset.bottom = insets.bottom
    }

    private var contentInset: UIEdgeInsets {
        if let contentInset = documentViewDelegate?.pdfDocumentViewContentInset(self) {
            return contentInset
        }

        // We apply the window's safe area insets (representing the system
        // status bar, but ignoring app bars) on iPhones only because in most
        // cases we prefer to display the content edge-to-edge.
        // iPhones are a special case because they are the only devices with a
        // physical notch (or Dynamic Island) which is included in the window's
        // safe area insets. Therefore, we must always take it into account to
        // avoid hiding the content.
        if UIDevice.current.userInterfaceIdiom == .phone {
            return window?.safeAreaInsets ?? .zero
        } else {
            // Edge-to-edge on macOS and iPadOS.
            return .zero
        }
    }

    override public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        super.canPerformAction(action, withSender: sender) && editingActions.canPerformAction(action)
    }

    override public func copy(_ sender: Any?) {
        Task {
            await editingActions.copy()
        }
    }

    @available(iOS 13.0, *)
    override public func buildMenu(with builder: UIMenuBuilder) {
        editingActions.buildMenu(with: builder)
        super.buildMenu(with: builder)
    }

    var isPaginated: Bool {
        isUsingPageViewController || displayMode == .twoUp || displayMode == .singlePage
    }

    var isSpreadEnabled: Bool {
        displayMode == .twoUp || displayMode == .twoUpContinuous
    }

    /// Returns whether the document is currently zoomed to match the given
    /// `fit`.
    func isAtScaleFactor(for fit: Fit) -> Bool {
        let scaleFactorToFit = scaleFactor(for: fit)
        // 1% tolerance for floating point comparison
        let tolerance: CGFloat = 0.01
        return abs(scaleFactor - scaleFactorToFit) < tolerance
    }

    /// Calculates the appropriate scale factor based on the fit preference.
    ///
    /// Only used in scroll mode, as the paginated mode doesn't support custom
    /// scale factors without visual hiccups when swiping pages.
    func scaleFactor(for fit: Fit) -> CGFloat {
        // While a `width` fit works in scroll mode, the pagination mode has
        // critical limitations when zooming larger than the page fit, so it
        // does not support a `width` fit.
        //
        // - Visual snap: There is no API to pre-set the zoom scale for the next
        //   page. PDFView resets the scale per page, causing a visible snap
        //   when swiping. We don’t see the issue with edge taps.
        // - Incorrect anchoring: When zooming larger than the page fit, the
        //   viewport centers vertically instead of showing the top. The API to
        //   fix this works in scroll mode but is ignored in paginated mode.
        //
        // So we only support a `page` fit in paginated mode.
        if isPaginated {
            return scaleFactorForSizeToFitVisiblePages
        }

        switch fit {
        case .auto, .width:
            // Use PDFKit's default auto-fit behavior
            return scaleFactorForSizeToFit
        case .page:
            return scaleFactorForLargestPage
        }
    }

    /// Calculates the scale factor to fit the visible pages (by area) to the
    /// viewport.
    private var scaleFactorForSizeToFitVisiblePages: CGFloat {
        // The native `scaleFactorForSizeToFit` is incorrect when displaying
        // paginated spreads, so we need to use a custom implementation.
        if !isPaginated || !isSpreadEnabled {
            scaleFactorForSizeToFit
        } else {
            calculateScale(
                for: spreadSize(for: visiblePages),
                viewSize: bounds.size,
                insets: contentInset
            )
        }
    }

    /// Calculates the scale factor to fit the largest page or spread (by area)
    /// to the viewport.
    private var scaleFactorForLargestPage: CGFloat {
        guard let document = document else {
            return 1.0
        }

        // Check cache before expensive calculation
        let viewSize = bounds.size
        let insets = contentInset
        if
            let cached = cachedScaleFactorForLargestPage,
            cached.document == ObjectIdentifier(document),
            cached.viewSize == viewSize,
            cached.contentInset == insets,
            cached.spread == isSpreadEnabled,
            cached.displaysAsBook == displaysAsBook
        {
            return cached.scaleFactor
        }

        var maxSize: CGSize = .zero
        var maxArea: CGFloat = 0

        if !isSpreadEnabled {
            // No spreads: find largest individual page
            for pageIndex in 0 ..< document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                let pageSize = page.bounds(for: displayBox).size
                let area = pageSize.width * pageSize.height

                if area > maxArea {
                    maxArea = area
                    maxSize = pageSize
                }
            }
        } else {
            // Spreads enabled: find largest spread
            let pageCount = document.pageCount

            if displaysAsBook, pageCount > 0 {
                // First page displayed alone - check its size
                if let firstPage = document.page(at: 0) {
                    let firstSize = firstPage.bounds(for: displayBox).size
                    let firstArea = firstSize.width * firstSize.height
                    if firstArea > maxArea {
                        maxArea = firstArea
                        maxSize = firstSize
                    }
                }
            }

            // Check spreads (pairs of pages)
            let startIndex = displaysAsBook ? 1 : 0
            for pageIndex in stride(from: startIndex, to: pageCount, by: 2) {
                let leftIndex = pageIndex
                let rightIndex = pageIndex + 1

                guard let leftPage = document.page(at: leftIndex) else { continue }

                if rightIndex < pageCount, let rightPage = document.page(at: rightIndex) {
                    // Two-page spread
                    let currentSpreadSize = spreadSize(for: [leftPage, rightPage])
                    let spreadArea = currentSpreadSize.width * currentSpreadSize.height

                    if spreadArea > maxArea {
                        maxArea = spreadArea
                        maxSize = currentSpreadSize
                    }
                } else {
                    // Last page alone (odd page count)
                    let leftSize = leftPage.bounds(for: displayBox).size
                    let singleArea = leftSize.width * leftSize.height
                    if singleArea > maxArea {
                        maxArea = singleArea
                        maxSize = leftSize
                    }
                }
            }
        }

        let scale = calculateScale(
            for: maxSize,
            viewSize: viewSize,
            insets: insets
        )

        cachedScaleFactorForLargestPage = (
            document: ObjectIdentifier(document),
            scaleFactor: scale,
            viewSize: viewSize,
            contentInset: insets,
            spread: isSpreadEnabled,
            displaysAsBook: displaysAsBook
        )
        return scale
    }

    /// Cache for expensive largest page scale calculation.
    private var cachedScaleFactorForLargestPage: (
        document: ObjectIdentifier,
        scaleFactor: CGFloat,
        viewSize: CGSize,
        contentInset: UIEdgeInsets,
        spread: Bool,
        displaysAsBook: Bool
    )?

    /// Calculates the combined size of pages laid out side-by-side horizontally.
    private func spreadSize(for pages: [PDFPage]) -> CGSize {
        var size = CGSize.zero
        for page in pages {
            let pageBounds = page.bounds(for: displayBox)
            size.height = max(size.height, pageBounds.height)
            size.width += pageBounds.width
        }
        return size
    }

    /// Calculates the scale factor needed to fit the given content size within
    /// the available viewport, accounting for content insets.
    private func calculateScale(
        for contentSize: CGSize,
        viewSize: CGSize,
        insets: UIEdgeInsets
    ) -> CGFloat {
        guard contentSize.width > 0, contentSize.height > 0 else {
            return 1.0
        }

        let availableSize = CGSize(
            width: viewSize.width - insets.left - insets.right,
            height: viewSize.height - insets.top - insets.bottom
        )

        let widthScale = availableSize.width / contentSize.width
        let heightScale = availableSize.height / contentSize.height

        // Use the smaller scale to ensure both dimensions fit
        return min(widthScale, heightScale)
    }
}
