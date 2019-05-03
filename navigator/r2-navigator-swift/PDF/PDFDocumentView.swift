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
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return super.canPerformAction(action, withSender: sender) && editingActions.canPerformAction(action)
    }

    public override func copy(_ sender: Any?) {
        guard editingActions.requestCopy() else {
            return
        }
        super.copy(sender)
    }
    
}
