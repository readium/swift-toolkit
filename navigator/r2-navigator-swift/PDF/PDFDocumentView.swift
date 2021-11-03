//
//  PDFView.swift
//  r2-navigator-swift
//
//  Created by Mickaël Menu on 03.04.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import PDFKit

@available(iOS 11.0, *)
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

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateContentInset()
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateContentInset()
    }
    
    private func updateContentInset() {
        // Setting the horizontal values triggers shifts the content incorrectly, somehow.
        firstScrollView?.contentInset.top = notchAreaInsets.top
        firstScrollView?.contentInset.bottom = notchAreaInsets.bottom
    }

    public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return super.canPerformAction(action, withSender: sender) && editingActions.canPerformAction(action)
    }

    public override func copy(_ sender: Any?) {
        editingActions.copy()
    }

}
