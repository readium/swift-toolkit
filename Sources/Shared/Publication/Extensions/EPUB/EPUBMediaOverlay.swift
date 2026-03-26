//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// EPUB Media Overlay metadata.
/// https://readium.org/webpub-manifest/profiles/epub#5-metadata
public struct EPUBMediaOverlay: Equatable, Sendable, JSONValueDecodable, JSONObjectEncodable {
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

    public init?(json: JSONValue?, warnings: WarningLogger? = nil) {
        guard let jsonObject = json?.object else { return nil }
        
        self.activeClass = jsonObject["activeClass"]?.string
        self.playbackActiveClass = jsonObject["playbackActiveClass"]?.string
        
        guard self.activeClass != nil || self.playbackActiveClass != nil else { return nil }
    }

    public var jsonObject: [String: JSONValue] {
        .init([
            "activeClass": activeClass,
            "playbackActiveClass": playbackActiveClass
        ])
    }
}
