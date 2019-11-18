//
//  EditingAction.swift
//  r2-navigator-swift
//
//  Created by Aferdita Muriqi, Mickaël Menu on 03.04.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import R2Shared


public enum EditingAction: String {
    case copy = "copy:"
    case share = "shareSelection:"
    case lookup = "_lookup:"
    
    public static var defaultActions: [EditingAction] {
        return [copy, share, lookup]
    }
}


protocol EditingActionsControllerDelegate: AnyObject {
    
    func editingActionsDidPreventCopy(_ editingActions: EditingActionsController)
    
}


/// Handles the authorization and check of editing actions.
final class EditingActionsController {
    
    public weak var delegate: EditingActionsControllerDelegate?

    private let actions: [EditingAction]
    private let license: DRMLicense?

    init(actions: [EditingAction], license: DRMLicense?) {
        self.actions = actions
        self.license = license
    }

    func canPerformAction(_ action: Selector) -> Bool {
        for editingAction in self.actions {
            if action == Selector(editingAction.rawValue) {
                return true
            }
        }
        return false
    }
    
    
    // MARK: - Selection
    
    /// Current user selection contents and frame in the publication view.
    private var selection: (text: String, frame: CGRect)?
    
    /// Peeks into the available selection contents authorized for copy.
    /// To be used only when required to have the contents before actually using it (eg. Share dialog). To consume the actual copy, use `copy()`.
    var selectionAuthorizedForCopy: (text: String, frame: CGRect)? {
        guard canCopy,
            var selection = selection else
        {
            return nil
        }
        if let license = license {
            guard let authorizedText = license.copy(selection.text, consumes: false) else {
                return nil
            }
            selection.text = authorizedText
        }
        return selection
    }
    
    /// To be called when the user selection changed.
    func selectionDidChange(_ selection: (text: String, frame: CGRect)?) {
        self.selection = selection
    }

    
    // MARK: - Copy

    /// Returns whether the copy interaction is at all allowed. It doesn't guarantee that the next copy action will be valid, if the license cancels it.
    var canCopy: Bool {
        return actions.contains(.copy) && (license?.canCopy ?? true)
    }

    /// Copies the authorized portion of the selection text into the pasteboard.
    func copy() {
        guard canCopy else {
            delegate?.editingActionsDidPreventCopy(self)
            return
        }
        guard var text = selection?.text else {
            return
        }
        
        if let license = license {
            guard let authorizedText = license.copy(text, consumes: true) else {
                return
            }
            text = authorizedText
        }
        
        UIPasteboard.general.string = text
    }
    
    
    // MARK: - Share
    
    /// Builds a UIActivityViewController to share the authorized contents of the user selection.
    func makeShareViewController(from contentsView: UIView) -> UIActivityViewController? {
        guard canCopy else {
            delegate?.editingActionsDidPreventCopy(self)
            return nil
        }
        guard let selection = selectionAuthorizedForCopy else {
            return nil
        }
        let viewController = UIActivityViewController(activityItems: [selection.text], applicationActivities: nil)
        viewController.completionWithItemsHandler = { _, completed, _, _ in
            if (completed) {
                self.copy()
            }
        }
        viewController.popoverPresentationController?.sourceView = contentsView
        viewController.popoverPresentationController?.sourceRect = selection.frame
        return viewController
    }
    
}
