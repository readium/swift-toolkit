//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UIKit

/// A navigator able to render arbitrary decorations over a publication.
public protocol DecorableNavigator {
    /// Declares the current state of the decorations in the given decoration `group`.
    ///
    /// The Navigator will decide when to actually render each decoration efficiently. Your only responsibility is to
    /// submit the updated list of decorations when there are changes.
    /// Name each decoration group as you see fit. A good practice is to use the name of the feature requiring
    /// decorations, e.g. `annotation`, `search`, `tts`, etc.
    func apply(decorations: [Decoration], in group: String)

    /// Indicates whether the Navigator supports the given decoration `style`.
    ///
    /// You should check whether the Navigator supports drawing the decoration styles required by a particular feature
    /// before enabling it. For example, underlining an audiobook does not make sense, so an Audiobook Navigator would
    /// not support the `underline` decoration style.
    func supports(decorationStyle style: Decoration.Style.Id) -> Bool

    /// Registers new callbacks for decoration interactions in the given `group`.
    ///
    /// - Parameter onActivated: Called when the user activates the decoration, e.g. with a click or tap.
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
    /// Frame of the bounding rect for the decoration, in the coordinate of the navigator view. This is only useful in
    /// the context of a VisualNavigator.
    public let rect: CGRect?
    /// Event point of the interaction, in the coordinate of the navigator view. This is only useful in the context of a
    /// VisualNavigator.
    public let point: CGPoint?
}

/// A decoration is a user interface element drawn on top of a publication. It associates a `style` to be rendered with
/// a discrete `locator` in the publication.
///
/// For example, decorations can be used to draw highlights, images or buttons.
public struct Decoration: Hashable {
    /// An identifier for this decoration. It must be unique in the group the decoration is applied to.
    public var id: Id

    /// Location in the publication where the decoration will be rendered.
    public var locator: Locator

    /// Declares the look and feel of the decoration.
    public var style: Style

    /// Additional context data specific to a reading app. Readium does not use it.
    public var userInfo: [AnyHashable: AnyHashable]

    public init(id: Id, locator: Locator, style: Style, userInfo: [AnyHashable: AnyHashable] = [:]) {
        self.id = id
        self.style = style
        self.locator = locator
        self.userInfo = userInfo
    }

    /// Unique identifier for a decoration.
    public typealias Id = String

    /// The Decoration Style determines the look and feel of a decoration once rendered by a Navigator.
    ///
    /// It is media type agnostic, meaning that each Navigator will translate the style into a set of rendering
    /// instructions which makes sense for the resource type.
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

            // Default Readium style IDs.

            public static let highlight: Id = "highlight"
            public static let underline: Id = "underline"
        }

        public static func highlight(tint: UIColor? = nil, isActive: Bool = false) -> Style {
            .init(id: .highlight, config: HighlightConfig(tint: tint, isActive: isActive))
        }

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
