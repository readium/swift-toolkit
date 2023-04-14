//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared
import UIKit

/// An `EditingAction` is an item in the text selection menu.
///
/// iOS provides default actions for copy, share, etc. (see `UIMenuController`), but you can provide custom actions
/// with `EditingAction(title: "Highlight", action: #selector(highlight:))`. Then, implement the selector in one of your
/// classes in the responder chain. Typically, in the `UIViewController` wrapping the navigator view controller.
public struct EditingAction: Hashable {
    /// Default editing actions enabled in the navigator.
    public static var defaultActions: [EditingAction] {
        [copy, share, define, lookup, translate]
    }

    /// Copy the text selection.
    public static let copy = EditingAction(kind: .native("copy:"))

    /// Look up the text selection in the dictionary and other sources.
    ///
    /// Not available on iOS 16+
    public static let lookup = EditingAction(kind: .native("_lookup:"))

    /// Look up the text selection in the dictionary (and other sources on iOS 16+).
    ///
    /// On iOS 16+, enabling this action will show two items: Look Up and Search Web.
    public static let define = EditingAction(kind: .native("_define:"))

    /// Translate the text selection.
    public static let translate = EditingAction(kind: .native("_translate:"))

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
        case let .native(action):
            return Selector(action)
        case let .custom(item):
            return item.action
        }
    }

    var menuItem: UIMenuItem? {
        switch kind {
        case .native:
            return nil
        case let .custom(item):
            return item
        }
    }
}

protocol EditingActionsControllerDelegate: AnyObject {
    func editingActionsDidPreventCopy(_ editingActions: EditingActionsController)
    func editingActions(_ editingActions: EditingActionsController, shouldShowMenuForSelection selection: Selection) -> Bool
    func editingActions(_ editingActions: EditingActionsController, canPerformAction action: EditingAction, for selection: Selection) -> Bool
}

/// Handles the authorization and check of editing actions.
final class EditingActionsController {
    weak var delegate: EditingActionsControllerDelegate?

    private let actions: [EditingAction]
    private let rights: UserRights
    private var isEnabled = true

    init(actions: [EditingAction], rights: UserRights) {
        self.actions = actions
        self.rights = rights
    }

    /// Current user selection contents and frame in the publication view.
    var selection: Selection? {
        didSet {
            if let selection = selection {
                isEnabled = delegate?.editingActions(self, shouldShowMenuForSelection: selection) ?? true
            } else {
                isEnabled = false
            }
            updateSharedMenuController()
        }
    }

    func canPerformAction(_ selector: Selector) -> Bool {
        guard
            isEnabled,
            let selection = selection,
            let action = actions.first(where: { $0.action == selector })
        else {
            return false
        }

        return delegate?.editingActions(self, canPerformAction: action, for: selection) ?? true
    }

    func canPerformAction(_ action: EditingAction) -> Bool {
        canPerformAction(action.action)
    }

    @available(iOS 13.0, *)
    func buildMenu(with builder: UIMenuBuilder) {
        // On iOS 16, there's a new "Search Web" menu item which is required
        // to enable the define action.
        if #available(iOS 16.0, *), !actions.contains(.define) {
            builder.remove(menu: .lookup)
        }
    }

    func updateSharedMenuController() {
        var items: [UIMenuItem] = []
        if isEnabled, let selection = selection {
            items = actions
                .filter { delegate?.editingActions(self, canPerformAction: $0, for: selection) ?? true }
                .compactMap(\.menuItem)
        }
        UIMenuController.shared.menuItems = items
        UIMenuController.shared.update()
    }

    // MARK: - Copy

    /// Returns whether the copy interaction is at all allowed. It doesn't guarantee that the next copy action will be valid, if the license cancels it.
    var canCopy: Bool {
        canPerformAction(.copy) && rights.canCopy
    }

    /// Copies the authorized portion of the selection text into the pasteboard.
    func copy() {
        guard let text = selection?.locator.text.highlight else {
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
        guard
            let selection = selection,
            let text = selection.locator.text.highlight
        else {
            return nil
        }
        guard canCopy, rights.canCopy(text: text) else {
            delegate?.editingActionsDidPreventCopy(self)
            return nil
        }

        let viewController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        viewController.completionWithItemsHandler = { _, completed, _, _ in
            if completed {
                self.copy()
            }
        }
        viewController.popoverPresentationController?.sourceView = contentsView
        viewController.popoverPresentationController?.sourceRect = selection.frame ?? .zero
        return viewController
    }
}
