//
//  Copyright 2025 Readium Foundation. All rights reserved.
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
        let insets = documentViewDelegate?.pdfDocumentViewContentInset(self) ?? window?.safeAreaInsets ?? .zero
        firstScrollView?.contentInset.top = insets.top
        firstScrollView?.contentInset.bottom = insets.bottom
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

    /// Calculates the appropriate scale factor based on the fit preference.
    ///
    /// Only used in scroll mode, as the paginated mode doesn't support custom
    /// scale factors without visual hiccups when swiping pages.
    func scaleFactor(for fit: Fit, contentInset: UIEdgeInsets) -> CGFloat {
        // While a custom fit works in scroll mode, the paginated mode has
        // critical limitations when zooming larger than the page fit.
        //
        // - Visual snap: There is no API to pre-set the zoom scale for the next
        //   page. ⁠PDFView resets the scale per page, causing a visible snap
        //   when swiping. We don’t see the issue with edge taps.
        // - Incorrect anchoring: When zooming larger than the page fit, the
        //   viewport centers vertically instead of showing the top. The API to
        //   fix this works in scroll mode but is ignored in paginated mode.
        guard !isPaginated else {
            return scaleFactorForSizeToFit
        }

        switch fit {
        case .auto, .width:
            // Use PDFKit's default auto-fit behavior
            return scaleFactorForSizeToFit
        case .page:
            return scaleFactorForLargestPage(contentInset: contentInset)
        }
    }

    /// Calculates the scale factor to fit the largest page or spread (by area)
    /// to the viewport.
    private func scaleFactorForLargestPage(
        contentInset: UIEdgeInsets
    ) -> CGFloat {
        guard let document = document else {
            return 1.0
        }

        let spread = (displayMode == .twoUp || displayMode == .twoUpContinuous)

        // Check cache before expensive calculation
        let viewSize = bounds.size
        if
            let cached = cachedScaleFactorForLargestPage,
            cached.document == ObjectIdentifier(document),
            cached.viewSize == viewSize,
            cached.contentInset == contentInset,
            cached.spread == spread,
            cached.displaysAsBook == displaysAsBook
        {
            return cached.scaleFactor
        }

        var maxSize: CGSize = .zero
        var maxArea: CGFloat = 0

        if !spread {
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
                let leftSize = leftPage.bounds(for: displayBox).size

                if rightIndex < pageCount, let rightPage = document.page(at: rightIndex) {
                    // Two-page spread
                    let rightSize = rightPage.bounds(for: displayBox).size
                    let spreadSize = CGSize(
                        width: leftSize.width + rightSize.width,
                        height: max(leftSize.height, rightSize.height)
                    )
                    let spreadArea = spreadSize.width * spreadSize.height

                    if spreadArea > maxArea {
                        maxArea = spreadArea
                        maxSize = spreadSize
                    }
                } else {
                    // Last page alone (odd page count)
                    let singleArea = leftSize.width * leftSize.height
                    if singleArea > maxArea {
                        maxArea = singleArea
                        maxSize = leftSize
                    }
                }
            }
        }

        var scale: CGFloat = 1.0
        if maxSize.width > 0, maxSize.height > 0 {
            // Account for content insets
            let availableSize = CGSize(
                width: viewSize.width - contentInset.left - contentInset.right,
                height: viewSize.height - contentInset.top - contentInset.bottom
            )

            let widthScale = availableSize.width / maxSize.width
            let heightScale = availableSize.height / maxSize.height

            // Use the smaller scale to ensure both dimensions fit
            scale = min(widthScale, heightScale)
        }

        cachedScaleFactorForLargestPage = (
            document: ObjectIdentifier(document),
            scaleFactor: scale,
            viewSize: viewSize,
            contentInset: contentInset,
            spread: spread,
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
}
