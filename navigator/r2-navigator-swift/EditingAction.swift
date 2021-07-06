//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UIKit
import R2Shared

/// An `EditingAction` is an item in the text selection menu.
///
/// iOS provides default actions for copy, share, etc. (see `UIMenuController`), but you can provide custom actions
/// with `EditingAction(title: "Highlight", action: #selector(highlight:))`. Then, implement the selector in one of your
/// classes in the responder chain. Typically, in the `UIViewController` wrapping the navigator view controller.
public struct EditingAction: Hashable {

    /// Default editing actions enabled in the navigator.
    public static var defaultActions: [EditingAction] {
        [copy, share, lookup]
    }

    /// Copy the text selection.
    public static let copy = EditingAction(kind: .native("copy:"))

    /// Look up the text selection in the dictionary.
    public static let lookup = EditingAction(kind: .native("_lookup:"))

    /// Share the text selection.
    ///
    /// Implementation detail: We use a custom share action to make sure the user is allowed to share the content. We
    /// can't override the native _share: action since it is private.
    public static let share = EditingAction(title: R2NavigatorLocalizedString("EditingAction.share"), action: #selector(EPUBSpreadView.shareSelection))

    /// Create a custom editing action.
    ///
    /// You need to implement the selector in one of your classes in the responder chain. Typically, in the
    /// `UIViewController` wrapping the navigator view controller.
    public init(title: String, action: Selector) {
        self.init(kind: .custom(UIMenuItem(title: title, action: action)))
    }

    enum Kind: Hashable {
        case native(String)
        case custom(UIMenuItem)
    }

    let kind: Kind

    init(kind: Kind) {
        self.kind = kind
    }

    var action: Selector {
        switch kind {
        case .native(let action):
            return Selector(action)
        case .custom(let item):
            return item.action
        }
    }

    var menuItem: UIMenuItem? {
        switch kind {
        case .native:
            return nil
        case .custom(let item):
            return item
        }
    }
}

protocol EditingActionsControllerDelegate: AnyObject {

    func editingActionsDidPreventCopy(_ editingActions: EditingActionsController)
    
}


/// Handles the authorization and check of editing actions.
final class EditingActionsController {

    weak var delegate: EditingActionsControllerDelegate?

    private let actions: [EditingAction]
    private let rights: UserRights

    init(actions: [EditingAction], rights: UserRights) {
        self.actions = actions
        self.rights = rights
    }

    func canPerformAction(_ action: Selector) -> Bool {
        actions.contains { $0.action == action }
    }

    func updateSharedMenuController() {
        UIMenuController.shared.menuItems = actions.compactMap { $0.menuItem }
        UIMenuController.shared.update()
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
        actions.contains(.copy) && rights.canCopy
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
