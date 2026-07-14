//
//  Copyright 2026 Readium Foundation. All rights reserved.
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

    /// The `UIMenuItem` backing a custom action, or nil for native actions.
    var menuItem: UIMenuItem? {
        switch kind {
        case .native:
            return nil
        case let .custom(item):
            return item
        }
    }

    /// Whether this is a custom (non-native) action.
    var isCustom: Bool {
        if case .custom = kind { return true }
        return false
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

    /// Whether a custom `action` should be inserted into the iOS 16+ edit menu
    /// built by `buildMenu(with:)`.
    ///
    /// The EPUB text selection is delivered asynchronously: the JS
    /// `selectionchange` event is debounced (~50 ms) and posted over the
    /// WKWebView message bridge, so on a double-tap (single-word) selection the
    /// edit menu can be built *before* `selection` is populated. During that
    /// window the action is shown unconditionally — preserving the double-tap
    /// fix — and the host app's menu suppression (`shouldShowMenuForSelection`)
    /// and per-action gating (`canPerformAction(_:for:)`) take effect once the
    /// selection is known.
    func shouldShowCustomAction(_ action: EditingAction) -> Bool {
        guard action.isCustom else { return false }
        guard selection != nil else { return true }
        return canPerformAction(action)
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

        // Custom actions are inserted into the selection edit menu via
        // `buildMenu` only on iOS 16+, where `UIEditMenuInteraction` consults
        // it synchronously — fixing the double-tap race where the menu appeared
        // before the async JS→native selection pipeline populated the legacy
        // `UIMenuController` items. On iOS 15 they are provided through
        // `updateSharedMenuController()` instead.
        //
        // `shouldShowCustomAction` honors the host app's suppression /
        // per-action gating once the selection is known, while still showing
        // the actions during the async-selection window (see its doc comment).
        guard #available(iOS 16.0, *) else { return }

        let customActions: [UIAction] = actions
            .filter(shouldShowCustomAction)
            .compactMap(\.menuItem)
            .map { item in
                UIAction(title: item.title) { _ in
                    // Dispatch through the responder chain (starting at the
                    // current first responder), so the host app's selector
                    // implementation is reached.
                    UIApplication.shared.sendAction(item.action, to: nil, from: nil, for: nil)
                }
            }

        if !customActions.isEmpty {
            let menu = UIMenu(title: "", options: .displayInline, children: customActions)
            builder.insertChild(menu, atStartOfMenu: .standardEdit)
        }
    }

    func updateSharedMenuController() {
        if #available(iOS 16.0, *) {
            // The text-selection edit menu (`UIEditMenuInteraction`) is built
            // through `buildMenu(with:)`, so custom actions are inserted there.
            // `UIMenuController` is unused; clear any stale items.
            UIMenuController.shared.menuItems = []
        } else {
            // On iOS 15 the selection callout still uses `UIMenuController`,
            // which is not consulted by `buildMenu`. Populate its items here.
            var items: [UIMenuItem] = []
            if isEnabled, let selection = selection {
                items = actions
                    .filter { delegate?.editingActions(self, canPerformAction: $0, for: selection) ?? true }
                    .compactMap(\.menuItem)
            }
            UIMenuController.shared.menuItems = items
            UIMenuController.shared.update()
        }
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
