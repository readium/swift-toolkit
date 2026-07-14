//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import Testing
import UIKit

/// Unit tests for the `shouldShowCustomAction(_:)` gating predicate that
/// `buildMenu(with:)` uses to decide which custom actions to insert into the
/// iOS 16+ edit menu.
///
/// Scope: these tests cover the *decision* of whether a custom action should
/// appear — its delegate gating (`shouldShowMenuForSelection`,
/// `canPerformAction(_:for:)`) and the deliberate "show during the async
/// selection window" behavior from PR #822. They do **not** exercise the menu
/// construction or the action dispatch, which live in `buildMenu(with:)` and
/// require a live `UIMenuBuilder` / responder chain.
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

    private let highlight = EditingAction(title: "Highlight", action: Selector(("highlight:")))

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

    /// Regression guard for the #822 double-tap race: the EPUB selection is
    /// delivered asynchronously, so the edit menu can be built before `selection`
    /// is set. The custom action must still be shown in that window — otherwise
    /// it disappears on single-word (double-tap) selections.
    @Test("custom action shown during the async-selection window (no selection yet)")
    func shownDuringAsyncSelectionWindow() {
        let delegate = FakeDelegate()
        let controller = makeController(delegate)
        // No selection set — simulates buildMenu firing before the async
        // selection pipeline delivered the selection.

        #expect(controller.shouldShowCustomAction(highlight))
    }

    /// Baseline check on the pre-existing native gating: `canPerformAction`
    /// returns false when the host suppresses the menu. This does not exercise
    /// any custom-action code — it documents the native behavior that
    /// `shouldShowCustomAction` defers to once a selection is known.
    @Test("native action remains gated by suppression")
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
