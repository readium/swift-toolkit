//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// A single unit of playback in a publication.
///
/// Each item carries the ``content`` to render, its structural ``roles`` for
/// skippability and escapability, and optional textual or visual alternates.
public struct PlaybackItem: Sendable {
    /// The content to render for this item.
    public var content: Content

    /// Semantic roles of this item (e.g. `paragraph`, `footnote`, `pagebreak`).
    ///
    /// Used by the player to apply skippability rules: the user can configure
    /// certain roles to be silently skipped during playback.
    public var roles: [ContentRole]

    /// Roles of all enclosing containers, ordered innermost to outermost.
    ///
    /// Used by the player to determine escapability: the user can jump out of
    /// a container (e.g. a `table`) whose role is marked as escapable.
    ///
    /// Empty for items with no structural containers (e.g. top-level audiobook
    /// resources).
    public var enclosingRoles: [ContentRole]

    /// Plain-text equivalent of the content, used for display or accessibility
    /// purposes (e.g. as a caption while audio plays).
    ///
    /// Distinct from ``textAlternate``, which points to a full alternate
    /// resource in the publication rather than an inline string.
    public var text: String?

    /// Reference to a textual alternate resource for this playback item
    /// (e.g. a synchronized HTML transcript).
    public var textAlternate: (any ResourceReference)?

    /// Reference to an image alternate resource for this playback item
    /// (e.g. a comic panel or illustration associated with the current
    /// audio segment).
    public var imageAlternate: (any ResourceReference)?

    public init(
        content: Content,
        roles: [ContentRole] = [],
        enclosingRoles: [ContentRole] = [],
        text: String? = nil,
        textAlternate: (any ResourceReference)? = nil,
        imageAlternate: (any ResourceReference)? = nil
    ) {
        self.content = content
        self.roles = roles
        self.enclosingRoles = enclosingRoles
        self.text = text
        self.textAlternate = textAlternate
        self.imageAlternate = imageAlternate
    }

    /// The content carried by a ``PlaybackItem``.
    ///
    /// A playback item is either an audio clip to play directly, or a piece of
    /// text to be synthesized by a TTS engine.
    public enum Content: Hashable, Sendable {
        /// An audio clip, optionally trimmed to a time range within the
        /// resource.
        case audio(AudioReference)

        /// Text to be synthesized by a TTS engine.
        case text(Text)

        /// Text content for synthesis by a TTS engine.
        public struct Text: Hashable, Sendable {
            /// Plain text to synthesize.
            public var text: String?

            /// SSML markup for TTS engines that support it, encoding prosody,
            /// pronunciation and other speech hints.
            public var ssml: SSML?

            /// Language of the text, so the TTS engine can select the correct
            /// voice and pronunciation rules.
            public var language: Language?

            public init?(
                text: String? = nil,
                ssml: SSML? = nil,
                language: Language? = nil
            ) {
                guard text != nil || ssml != nil else {
                    return nil
                }
                self.text = text
                self.ssml = ssml
                self.language = language
            }
        }
    }
}
