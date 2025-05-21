//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import PDFKit

public final class PDFDocumentView: PDFView {
    var editingActions: EditingActionsController

    init(frame: CGRect, editingActions: EditingActionsController) {
        self.editingActions = editingActions

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
        // Setting the horizontal values triggers shifts the content incorrectly, somehow.
        firstScrollView?.contentInset.top = notchAreaInsets.top
        firstScrollView?.contentInset.bottom = notchAreaInsets.bottom
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
}
