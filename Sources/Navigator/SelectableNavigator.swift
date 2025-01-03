//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UIKit

/// A navigator supporting user selection.
public protocol SelectableNavigator: Navigator {
    /// Currently selected content.
    var currentSelection: Selection? { get }

    /// Clears the current selection.
    func clearSelection()
}

/// Represents a user content selection in a navigator.
///
/// In the case of a text selection, you can get its content using `locator.text.highlight`.
public struct Selection {
    /// Location of the user selection in the `Publication`.
    public let locator: Locator

    /// Frame of the bounding rect for the selection, in the coordinate of the navigator view.
    ///
    /// This is only useful in the context of a `VisualNavigator`.
    public let frame: CGRect?
}

@MainActor public protocol SelectableNavigatorDelegate: NavigatorDelegate {
    /// Returns whether the default edit menu (`UIMenuController`) should be displayed for the given `selection`.
    ///
    /// To implement a custom selection pop-up, return false and display your own view using `selection.frame`.
    func navigator(_ navigator: SelectableNavigator, shouldShowMenuForSelection selection: Selection) -> Bool

    /// Returns whether the given `action` should be visible in the edit menu of the given `selection`.
    ///
    /// Implement this delegate method to validate the selection before showing a particular action. For example, making
    /// sure the selected text is not too large for a definition look up:
    ///
    ///     public func navigator(_ navigator: SelectableNavigator, canPerformAction action: EditingAction, for selection: Selection) -> Bool {
    ///         switch action {
    ///         case .lookup:
    ///             return (selection.locator.text.highlight?.count ?? 0) <= 50
    ///         default:
    ///             return true
    ///         }
    ///     }
    func navigator(_ navigator: SelectableNavigator, canPerformAction action: EditingAction, for selection: Selection) -> Bool
}

public extension SelectableNavigatorDelegate {
    func navigator(_ navigator: SelectableNavigator, shouldShowMenuForSelection selection: Selection) -> Bool { true }
    func navigator(_ navigator: SelectableNavigator, canPerformAction action: EditingAction, for selection: Selection) -> Bool { true }
}
