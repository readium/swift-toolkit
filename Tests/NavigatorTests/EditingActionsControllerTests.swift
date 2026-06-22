//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing
import UIKit

/// Custom editing actions must respect the same delegate gating as the native
/// ones: the host app can suppress the whole menu through
/// `shouldShowMenuForSelection` and disable individual actions through
/// `canPerformAction(_:for:)`. These tests guard against the custom-action menu
/// bypassing that gating (see PR #822).
@MainActor
@Suite("EditingActionsController custom action gating")
struct EditingActionsControllerTests {
    private final class FakeDelegate: EditingActionsControllerDelegate {
        var showsMenu = true
        /// Actions the host app disables through `canPerformAction(_:for:)`.
        var disabledActions: Set<EditingAction> = []

        func editingActionsDidPreventCopy(_ editingActions: EditingActionsController) {}

        func editingActions(_ editingActions: EditingActionsController, shouldShowMenuForSelection selection: Selection) -> Bool {
            showsMenu
        }

        func editingActions(_ editingActions: EditingActionsController, canPerformAction action: EditingAction, for selection: Selection) -> Bool {
            !disabledActions.contains(action)
        }
    }

    private let highlight = EditingAction(title: "Highlight", action: Selector("highlight:"))

    private let selection = Selection(
        locator: Locator(href: AnyURL(string: "chapter1.html")!, mediaType: .html),
        frame: nil
    )

    private func makeController(_ delegate: FakeDelegate) -> EditingActionsController {
        let publication = Publication(manifest: Manifest(metadata: Metadata(title: "Test"), links: [], readingOrder: []))
        let controller = EditingActionsController(actions: [highlight, .copy], publication: publication)
        controller.delegate = delegate
        return controller
    }

    @Test("custom action shown when the menu is enabled and the action is allowed")
    func shownWhenEnabled() {
        let delegate = FakeDelegate()
        let controller = makeController(delegate)
        controller.selection = selection

        #expect(controller.shouldShowCustomAction(highlight))
    }

    @Test("custom action suppressed when shouldShowMenuForSelection returns false")
    func suppressedByMenu() {
        let delegate = FakeDelegate()
        delegate.showsMenu = false
        let controller = makeController(delegate)
        controller.selection = selection

        #expect(!controller.shouldShowCustomAction(highlight))
    }

    @Test("custom action disabled when the delegate denies canPerformAction")
    func disabledByDelegate() {
        let delegate = FakeDelegate()
        delegate.disabledActions = [highlight]
        let controller = makeController(delegate)
        controller.selection = selection

        #expect(!controller.shouldShowCustomAction(highlight))
    }

    // Regression guard for the #822 double-tap race: the EPUB selection is
    // delivered asynchronously, so the edit menu can be built before `selection`
    // is set. The custom action must still be shown in that window — otherwise
    // it disappears on single-word (double-tap) selections.
    @Test("custom action shown during the async-selection window (no selection yet)")
    func shownDuringAsyncSelectionWindow() {
        let delegate = FakeDelegate()
        let controller = makeController(delegate)
        // No selection set — simulates buildMenu firing before the async
        // selection pipeline delivered the selection.

        #expect(controller.shouldShowCustomAction(highlight))
    }

    // Native actions stay gated by the canonical path, proving the custom-action
    // race fallback doesn't loosen native suppression.
    @Test("native action remains gated by suppression (parity)")
    func nativeActionGated() {
        let delegate = FakeDelegate()
        delegate.showsMenu = false
        let controller = makeController(delegate)
        controller.selection = selection

        #expect(!controller.canPerformAction(.copy))
    }

    // Guards the `guard action.isCustom else { return false }` in
    // `shouldShowCustomAction`: a native action must never be inserted into the
    // custom inline menu, even with an active selection (otherwise the
    // race-fallback branch could duplicate native items like Copy).
    @Test("native action is never shown as a custom menu action")
    func nativeActionNotCustom() {
        let delegate = FakeDelegate()
        let controller = makeController(delegate)
        controller.selection = selection

        #expect(!controller.shouldShowCustomAction(.copy))
    }
}
