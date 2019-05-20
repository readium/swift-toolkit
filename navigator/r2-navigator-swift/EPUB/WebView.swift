//
//  WebView.swift
//  r2-navigator-swift
//
//  Created by Mickaël Menu on 20.05.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import WebKit

/// A custom web view which:
///  - Forwards selection actions to an EditingActionsController.
final class WebView: WKWebView {
    
    private let editingActions: EditingActionsController
    
    init(editingActions: EditingActionsController) {
        self.editingActions = editingActions
        super.init(frame: .zero, configuration: .init())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func dismissUserSelection() {
        evaluateJavaScript("window.getSelection().removeAllRanges()")
        // Before iOS 12, we also need to disable user interaction to get rid of the selection overlays.
        isUserInteractionEnabled = false
        isUserInteractionEnabled = true
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return  super.canPerformAction(action, withSender: sender) && editingActions.canPerformAction(action)
    }
    
    override func copy(_ sender: Any?) {
        guard editingActions.requestCopy() else {
            return
        }
        super.copy(sender)
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        setupDragAndDrop()
    }

    private func setupDragAndDrop() {
        if !editingActions.canCopy {
            guard #available(iOS 11.0, *),
                let webScrollView = subviews.first(where: { $0 is UIScrollView }),
                let contentView = webScrollView.subviews.first(where: { $0.interactions.count > 1 }),
                let dragInteraction = contentView.interactions.first(where: { $0 is UIDragInteraction }) else
            {
                return
            }
            contentView.removeInteraction(dragInteraction)
        }
    }
    
}

