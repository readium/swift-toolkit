//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension RelativeURL {
    /// Creates a ``RelativeURL`` from a ZIP entry's stored file name.
    ///
    /// Per the ZIP specification (APPNOTE.TXT, 4.4.17.1), an entry name is "the
    /// name of the file, with optional relative path" and "MUST NOT contain a
    /// drive or device letter, or a leading slash" — i.e. it is a *relative*
    /// path. Some archives violate this and store absolute-looking names such
    /// as `/001.jpg` (notably CBZ comics packed by tools that don't strip the
    /// leading slash).
    ///
    /// Left untouched, such a name is interpreted as an absolute-path
    /// reference: when the manifest href `/001.jpg` is resolved against the
    /// publication server's base URL, the leading slash replaces the base path
    /// entirely, producing a request that no longer maps to the archive entry
    /// and 404ing every resource. Stripping the leading slashes keeps the entry
    /// the relative path the format intends.
    init?(zipEntryPath path: String) {
        var path = Substring(path)
        while path.hasPrefix("/") {
            path = path.dropFirst()
        }
        guard !path.isEmpty else {
            return nil
        }
        self.init(path: String(path))
    }
}
