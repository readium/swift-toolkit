//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UIKit

/// An `EditingAction` is an item in the text selection menu.
///
/// iOS provides default actions for copy, share, etc. (see `UIMenuController`),
/// but you can provide custom actions with
/// `EditingAction(title: "Highlight", action: #selector(highlight:))`.
/// Then, implement the selector in one of your classes in the responder chain.
/// Typically, in the `UIViewController` wrapping the navigator view
/// controller.
public struct EditingAction: Hashable {
    /// Default editing actions enabled in the navigator.
    public static var defaultActions: [EditingAction] {
        [copy, share, lookup, translate]
    }

    /// Copy the text selection.
    public static let copy = EditingAction(kind: .native(["copy:"]))

    /// Look up the text selection in the dictionary and other sources.
    ///
    /// On iOS 16+, enabling this action will show two items: Look Up and
    /// Search Web.
    public static let lookup = EditingAction(kind: .native(["lookup", "_lookup:", "define:", "_define:"]))

    /// Translate the text selection.
    public static let translate = EditingAction(kind: .native(["translate:", "_translate:"]))

    /// Share the text selection.
    public static let share = EditingAction(kind: .native(["share:", "_share:"]))

    /// Create a custom editing action.
    ///
    /// You need to implement the selector in one of your classes in the
    /// responder chain. Typically, in the `UIViewController` wrapping the
    /// navigator view controller.
    public init(title: String, action: Selector) {
        self.init(kind: .custom(UIMenuItem(title: title, action: action)))
    }

    enum Kind: Hashable {
        case native([String])
        case custom(UIMenuItem)
    }

    let kind: Kind

    init(kind: Kind) {
        self.kind = kind
    }

    var actions: [Selector] {
        switch kind {
        case let .native(actions):
            return actions.map { Selector($0) }
        case let .custom(item):
            return [item.action]
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
    private let canShare: Bool
    private var isEnabled = true

    init(
        actions: [EditingAction],
        publication: Publication
    ) {
        self.actions = actions
        rights = publication.rights
        canShare = !publication.isProtected
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

    func canPerformAction(_ action: EditingAction) -> Bool {
        action.actions.contains { canPerformAction($0) }
    }

    func canPerformAction(_ selector: Selector) -> Bool {
        // Accessibility editing actions (e.g. Spoken Option in Accessibility
        // system settings) cannot be properly disabled.
        guard !selector.description.hasPrefix("_accessibility") else {
            return true
        }

        guard
            isEnabled,
            let selection = selection,
            let action = actions.first(where: { $0.actions.contains(selector) }),
            isActionAllowed(action)
        else {
            return false
        }

        return delegate?.editingActions(self, canPerformAction: action, for: selection) ?? true
    }

    /// Verifies that the user has the rights to use the given `action`.
    private func isActionAllowed(_ action: EditingAction) -> Bool {
        switch action {
        case .share:
            return canShare
        default:
            return true
        }
    }

    @available(iOS 13.0, *)
    func buildMenu(with builder: UIMenuBuilder) {
        if !canPerformAction(.lookup) {
            builder.remove(menu: .lookup)
        }
        if !canPerformAction(.share) {
            builder.remove(menu: .share)
        }

        // Learn is removed as it seems bugged on iOS 17: it opens a Text
        // Expansion setting which allows to copy the selection.
        // To reproduce, comment out and select Japanese text on a PDF.
        builder.remove(menu: .learn)
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

    /// Returns whether the copy interaction is at all allowed. It doesn't
    /// guarantee that the next copy action will be valid, if the license
    /// cancels it.
    var canCopy: Bool {
        canPerformAction(.copy)
    }

    /// Copies the authorized portion of the selection text into the pasteboard.
    @MainActor
    func copy() async {
        guard let text = selection?.locator.text.highlight else {
            return
        }
        guard await rights.copy(text: text) else {
            delegate?.editingActionsDidPreventCopy(self)
            return
        }

        UIPasteboard.general.string = text
    }
}
