//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

extension Locator {
    init(href: String, mediaType: MediaType, title: String? = nil, locations: Locations = .init(), text: Text = .init()) {
        self.init(href: AnyURL(string: href)!, mediaType: mediaType, title: title, locations: locations, text: text)
    }
}

extension TemporalSelector {
    /// Creates a position at the given valid `time`.
    init(position time: TimeInterval) {
        self = .position(TemporalPosition(time: time)!)
    }

    /// Creates a clip between the given valid times.
    init(start: TimeInterval, end: TimeInterval) {
        self = .clip(TemporalClip(start: start, end: end)!)
    }
}

extension ContentElement {
    func equatable() -> AnyEquatableContentElement {
        AnyEquatableContentElement(self)
    }
}
