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

    override public var document: PDFDocument? {
        didSet {
            // Remove annotation menu interactions after document is set, as PDFKit
            // may add them during document loading
            if #available(iOS 16.0, *) {
                removeAnnotationMenuInteractions()
            }
        }
    }

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

        // Prevent the default annotation context menu from appearing.
        // We use our own custom color picker menu for annotations.
        if #available(iOS 16.0, *) {
            removeAnnotationMenuInteractions()
        }
    }

    @available(iOS 16.0, *)
    private func removeAnnotationMenuInteractions() {
        // Remove all UIEditMenuInteraction instances which are responsible for
        // showing the annotation context menu on tap
        for interaction in interactions where interaction is UIEditMenuInteraction {
            removeInteraction(interaction)
        }
    }

    override public func addInteraction(_ interaction: UIInteraction) {
        // Prevent PDFKit from adding UIEditMenuInteraction which shows
        // the default annotation context menu. We use our own custom menu.
        if #available(iOS 16.0, *) {
            guard !(interaction is UIEditMenuInteraction) else {
                return
            }
        }
        super.addInteraction(interaction)
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

    /// Reader customization: gate system actions so only our custom highlight command remains.
    override public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if editingActions.handlesAction(action) {
            return editingActions.canPerformAction(action)
        }
        let disallowedSelectors: [Selector] = [
            #selector(UIResponderStandardEditActions.cut(_:)),
            #selector(UIResponderStandardEditActions.copy(_:)),
            #selector(UIResponderStandardEditActions.paste(_:)),
            #selector(UIResponderStandardEditActions.delete(_:)),
            #selector(UIResponderStandardEditActions.selectAll(_:))
        ]
        if disallowedSelectors.contains(action) {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
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

    /// Reader customization: forward the highlight selector to the hosting container instead of PDFKit.
    override public func target(forAction action: Selector, withSender sender: Any?) -> Any? {
        guard editingActions.handlesAction(action) else {
            return super.target(forAction: action, withSender: sender)
        }

        // Traverse the responder chain manually to find the first responder
        // that implements the action. Returning `next` is not sufficient
        // because UIKit will still send the action back to this view.
        var responder = next
        while let currentResponder = responder {
            if currentResponder.responds(to: action) {
                return currentResponder
            }
            responder = currentResponder.next
        }

        return nil
    }
}
