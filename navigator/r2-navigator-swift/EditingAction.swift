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

    var selector: Selector { Selector(rawValue) }
}


protocol EditingActionsControllerDelegate: AnyObject {
    
    func editingActionsDidPreventCopy(_ editingActions: EditingActionsController)
    
}


/// Handles the authorization and check of editing actions.
final class EditingActionsController {
    
    public weak var delegate: EditingActionsControllerDelegate?

    private let actions: [EditingAction]
    private let rights: UserRights

    init(actions: [EditingAction], rights: UserRights) {
        self.actions = actions
        self.rights = rights
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
    
    /// To be called when the user selection changed.
    func selectionDidChange(_ selection: (text: String, frame: CGRect)?) {
        self.selection = selection
    }

    
    // MARK: - Copy

    /// Returns whether the copy interaction is at all allowed. It doesn't guarantee that the next copy action will be valid, if the license cancels it.
    var canCopy: Bool {
        return actions.contains(.copy) && rights.canCopy
    }

    /// Copies the authorized portion of the selection text into the pasteboard.
    func copy() {
        guard let text = selection?.text else {
            return
        }
        guard rights.copy(text: text) else {
            delegate?.editingActionsDidPreventCopy(self)
            return
        }
        
        UIPasteboard.general.string = text
    }
    
    
    // MARK: - Share
    
    /// Builds a UIActivityViewController to share the authorized contents of the user selection.
    func makeShareViewController(from contentsView: UIView) -> UIActivityViewController? {
        // Peeks into the available selection contents authorized for copy.
        guard let selection = selection else {
            return nil
        }
        guard canCopy, rights.canCopy(text: selection.text) else {
            delegate?.editingActionsDidPreventCopy(self)
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
