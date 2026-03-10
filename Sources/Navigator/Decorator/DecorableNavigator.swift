//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UIKit

/// A navigator able to render arbitrary decorations over a publication.
public protocol DecorableNavigator {
    
    /// Declares the desired state of a named decoration `group`.
    ///
    /// Internally the navigator diffs the new list against the previous one
    /// and sends only the actual changes (additions, removals, updates) to the
    /// rendered content, grouped per resource.
    ///
    /// You can call apply freely on every state change without worrying about
    /// redundant work—the diffing makes it safe and efficient. The only thing
    /// you need to maintain is the current complete list.
    ///
    /// Name each decoration group as you see fit. A good practice is to use the
    /// name of the feature requiring decorations, e.g. `annotation`, `search`,
    /// `tts`, etc.
    func apply(decorations: [Decoration], in group: String)

    /// Indicates whether the Navigator supports the given decoration `style`.
    ///
    /// Check this before enabling a feature that depends on a specific style
    /// (e.g. do not offer underlining if the navigator does not support it).
    func supports(decorationStyle style: Decoration.Style.Id) -> Bool

    /// Registers a callback fired when the user clicks or taps a decoration in
    /// the given `group`.
    ///
    /// - Parameter onActivated: Called when the user activates the decoration,
    /// e.g. with a click or tap.
    func observeDecorationInteractions(inGroup group: String, onActivated: @escaping OnActivatedCallback)

    /// Called when the user activates a decoration, e.g. with a click or tap.
    typealias OnActivatedCallback = (_ event: OnDecorationActivatedEvent) -> Void
}

/// Holds the metadata about a decoration activation interaction.
public struct OnDecorationActivatedEvent {
    /// Activated decoration.
    public let decoration: Decoration
    
    /// Name of the group the decoration belongs to.
    public let group: String
    
    /// Frame of the bounding rect for the decoration, in the coordinate of the
    /// navigator view. This is only useful in the context of a VisualNavigator.
    public let rect: CGRect?
    
    /// Event point of the interaction, in the coordinate of the navigator view.
    /// This is only useful in the context of a VisualNavigator.
    public let point: CGPoint?
}

/// A Decoration is a single UI element overlaid on publication content.
///
/// It pairs a `locator` with a `style` and carries a stable id used to track
/// changes across updates.
public struct Decoration: Hashable {
    
    /// Uniquely identifies a decoration within its group.
    ///
    /// Tip: Use your model's database primary key here so you can look it up
    /// when the user taps the decoration.
    public var id: Id

    /// Location in the publication where the decoration will be rendered.
    public var locator: Locator

    /// Declares the look and feel of the decoration.
    public var style: Style

    /// Optional dictionary for attaching extra data specific to the application
    /// directly to the Decoration. Readium does not use it.
    public var userInfo: [AnyHashable: AnyHashable]

    public init(id: Id, locator: Locator, style: Style, userInfo: [AnyHashable: AnyHashable] = [:]) {
        self.id = id
        self.style = style
        self.locator = locator
        self.userInfo = userInfo
    }

    /// Unique identifier for a decoration.
    public typealias Id = String

    /// The Decoration Style determines the look and feel of a decoration once
    /// rendered by a Navigator.
    ///
    /// It is media type agnostic, meaning that each Navigator will translate
    /// the style into a set of rendering instructions which makes sense for the
    /// resource type.
    public struct Style: Hashable {
        /// Unique ID for a style.
        public struct Id: RawRepresentable, ExpressibleByStringLiteral, Hashable {
            public let rawValue: String
            public init(rawValue: String) {
                self.rawValue = rawValue
            }

            public init(stringLiteral value: StringLiteralType) {
                self.init(rawValue: value)
            }

            /// Semi-transparent color fill over the text.
            public static let highlight: Id = "highlight"
            
            /// Underline stroke beneath the text.
            public static let underline: Id = "underline"
        }

        /// Semi-transparent color fill over the text.
        ///
        /// When `tint` is `nil`, the template's `defaultTint` is used.
        ///
        /// Set `isActive: true` to render the decoration in an "active"
        /// variant: a filled highlight combined with an underline. Used for
        /// example to indicate the currently focused item (e.g. the selected
        /// search result or the sentence currently being spoken by TTS).
        public static func highlight(tint: UIColor? = nil, isActive: Bool = false) -> Style {
            .init(id: .highlight, config: HighlightConfig(tint: tint, isActive: isActive))
        }

        /// Underline stroke beneath the text.
        ///
        /// When `tint` is `nil`, the template's `defaultTint` is used.
        ///
        /// Set `isActive: true` to render the decoration in an "active"
        /// variant: a filled highlight combined with an underline. Used for
        /// example to indicate the currently focused item (e.g. the selected
        /// search result or the sentence currently being spoken by TTS).
        public static func underline(tint: UIColor? = nil, isActive: Bool = false) -> Style {
            .init(id: .underline, config: HighlightConfig(tint: tint, isActive: isActive))
        }

        public struct HighlightConfig: Hashable {
            public var tint: UIColor?
            public var isActive: Bool
            public init(tint: UIColor? = nil, isActive: Bool = false) {
                self.tint = tint
                self.isActive = isActive
            }
        }

        public let id: Id
        public let config: AnyHashable?

        public init(id: Id, config: AnyHashable? = nil) {
            self.id = id
            self.config = config
        }
    }

    public var json: [String: Any] {
        [
            "id": id,
            "locator": locator.json,
            "style": style.id.rawValue,
        ]
    }
}
