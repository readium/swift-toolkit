//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// EPUB Media Overlay metadata.
/// https://readium.org/webpub-manifest/profiles/epub#5-metadata
public struct EPUBMediaOverlay: Equatable, Sendable {
    /// Author-defined CSS class name to apply to the currently-playing EPUB
    /// Content Document element.
    public var activeClass: String?

    /// Author-defined CSS class name to apply to the EPUB Content Document's
    /// document element when playback is active.
    public var playbackActiveClass: String?

    public init(activeClass: String? = nil, playbackActiveClass: String? = nil) {
        self.activeClass = activeClass
        self.playbackActiveClass = playbackActiveClass
    }

    public init?(json: (any Sendable)?) {
        guard let json = json as? [String: any Sendable] else { return nil }
        activeClass = json["activeClass"] as? String
        playbackActiveClass = json["playbackActiveClass"] as? String
        guard activeClass != nil || playbackActiveClass != nil else { return nil }
    }

    public var json: [String: any Sendable] {
        makeJSON([
            "activeClass": encodeIfNotNil(activeClass),
            "playbackActiveClass": encodeIfNotNil(playbackActiveClass),
        ])
    }
}
