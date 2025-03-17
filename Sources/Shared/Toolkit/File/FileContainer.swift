//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Provides access to individual file resources on the local file system.
public final class FileContainer: Container, Loggable {
    private let files: [RelativeURL: FileURL]

    public let sourceURL: AbsoluteURL? = nil
    public let entries: Set<AnyURL>

    /// Provides access to a collection of local files.
    public init(files: [RelativeURL: FileURL]) {
        self.files = files
        entries = Set(files.keys.map(\.anyURL.normalized))
    }

    /// Provides access to the given local `file` at `href`.
    public convenience init(href: RelativeURL, file: FileURL) {
        self.init(files: [href: file])
    }

    public subscript(url: any URLConvertible) -> Resource? {
        guard
            let url = url.anyURL.relativeURL?.normalized,
            let file = files[url]
        else {
            return nil
        }
        return FileResource(file: file)
    }
}
