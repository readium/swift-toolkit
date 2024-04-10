//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

extension Fetcher {
    /// Returns the data of a file at given `link`.
    func readData(at link: Link?) throws -> Data? {
        guard let link = link else {
            return nil
        }
        let resource = get(link)
        defer { resource.close() }
        return try resource.read().get()
    }

    /// Returns the data of a file at given `href`.
    func readData<T: URLConvertible>(at href: T) throws -> Data {
        let resource = get(href)
        defer { resource.close() }
        return try resource.read().get()
    }

    /// Guesses a fetcher's archive title from its contents.
    ///
    /// If the `Fetcher` contains a single root directory, we assume it is the
    /// title. This is often the case for example with CBZ files.
    func guessTitle(ignoring: (Link) -> Bool = { _ in false }) -> String? {
        var title: String?

        for link in links {
            guard !ignoring(link) else {
                continue
            }
            guard
                let components = try? link.url().pathSegments,
                components.count > 1,
                title == nil || title == components.first
            else {
                return nil
            }
            title = components.first
        }

        return title
    }
}
