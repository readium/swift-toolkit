//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import WebKit

/// A custom web view which:
///  - Forwards copy: menu action to an EditingActionsController.
final class WebView: WKWebView {
    /// Gates copy, drag and the edit menu according to the rights of the
    /// publication being displayed.
    ///
    /// Mutable because a web view outlives the navigator that created it: once
    /// recycled for another publication it must stop enforcing the previous
    /// one's rights. Rebinding goes through ``rebind(editingActions:)``.
    ///
    /// `nil` on a pooled web view that no publication has claimed yet, in
    /// which case every editing action is denied.
    private var editingActions: EditingActionsController?

    convenience init(editingActions: EditingActionsController) {
        self.init(editingActions: editingActions, configuration: WKWebViewConfiguration())
    }

    /// Creates a web view that no publication is bound to yet.
    ///
    /// Until ``rebind(editingActions:)`` is called it denies every editing
    /// action, so a pooled web view cannot leak the rights of whichever
    /// publication reaches it first.
    init(configuration: WKWebViewConfiguration) {
        editingActions = nil

        super.init(frame: .zero, configuration: configuration)

        #if DEBUG && swift(>=5.8)
            if #available(macOS 13.3, iOS 16.4, *) {
                isInspectable = true
            }
        #endif
    }

    init(editingActions: EditingActionsController, configuration: WKWebViewConfiguration) {
        self.editingActions = editingActions

        super.init(frame: .zero, configuration: configuration)

        #if DEBUG && swift(>=5.8)
            if #available(macOS 13.3, iOS 16.4, *) {
                isInspectable = true
            }
        #endif
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Whether a publication's editing rights are bound to this web view. One
    /// idling in a pool must not be bound to any.
    var isBoundToPublication: Bool { editingActions != nil }

    /// Drops the editing rights of the publication this web view was
    /// displaying, denying every editing action until it is rebound.
    ///
    /// Called when a web view goes back to a pool, so that it stops keeping
    /// the publication's rights alive while it idles.
    func unbindFromPublication() {
        editingActions = nil

        // Leave the view in the state a freshly built one is in, rather than
        // with a drag interaction still torn out for a publication it no
        // longer displays.
        restoreDragAndDropIfNeeded()
    }

    /// Points this web view at another publication's editing rights.
    ///
    /// Must be called before a recycled web view is shown again: until it is,
    /// the view denies every editing action.
    func rebind(editingActions: EditingActionsController) {
        self.editingActions = editingActions

        // The drag interaction is *removed* for publications that disallow
        // copying, and removal is not undone by simply swapping the
        // controller. Restore it before re-applying the new rights, otherwise
        // a no-copy publication would leave drag broken for every publication
        // that reuses this web view.
        restoreDragAndDropIfNeeded()
        setupDragAndDrop()
    }

    func clearSelection() {
        evaluateJavaScript("window.getSelection().removeAllRanges()")
    }

    override func buildMenu(with builder: any UIMenuBuilder) {
        editingActions?.buildMenu(with: builder)

        // Don't call super as it is the only way to remove the
        // "Copy Link with Highlight" menu item.
        // See https://github.com/readium/swift-toolkit/issues/509
//        super.buildMenu(with: builder)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        super.canPerformAction(action, withSender: sender)
            && (editingActions?.canPerformAction(action) ?? false)
    }

    override func copy(_ sender: Any?) {
        guard let editingActions else {
            return
        }

        Task {
            await editingActions.copy()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        setupDragAndDrop()
    }

    /// The drag interaction removed for a publication that disallows copying,
    /// kept so that it can be restored if this web view is recycled for a
    /// publication that allows it.
    private var removedDragInteraction: (interaction: any UIInteraction, view: UIView)?

    private func setupDragAndDrop() {
        if !(editingActions?.canCopy ?? false) {
            guard
                removedDragInteraction == nil,
                let webScrollView = subviews.first(where: { $0 is UIScrollView }),
                let contentView = webScrollView.subviews.first(where: { $0.interactions.count > 1 }),
                let dragInteraction = contentView.interactions.first(where: { $0 is UIDragInteraction })
            else {
                return
            }
            contentView.removeInteraction(dragInteraction)
            removedDragInteraction = (dragInteraction, contentView)
        }
    }

    private func restoreDragAndDropIfNeeded() {
        guard let removed = removedDragInteraction else {
            return
        }

        removedDragInteraction = nil
        removed.view.addInteraction(removed.interaction)
    }
}
