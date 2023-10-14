//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

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
    func readData<T : URLConvertible>(at href: T) throws -> Data {
        let resource = get(href)
        defer { resource.close() }
        return try resource.read().get()
    }

    /// Guesses a fetcher's archive title from its contents.
    ///
    /// If the `Fetcher` contains a single root directory, we assume it is the title. This is
    /// often the case for example with CBZ files.
    func guessTitle(ignoring: (Link) -> Bool = { _ in false }) -> String? {
        let firstLink = links.first

        let directories = links
            .filter { !ignoring($0) }
            .compactMap { $0.href.removingPrefix("/").split(separator: "/", maxSplits: 1).first }
            .removingDuplicates()

        guard
            directories.count == 1,
            let title = directories.first.map(String.init),
            title != firstLink?.href.removingPrefix("/")
        else {
            return nil
        }

        return title
    }
}
