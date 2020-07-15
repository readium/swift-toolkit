//
//  Fetcher.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 08/06/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

extension Fetcher {

    /// Returns the data of a file at given `href`.
    func readData(at href: String) throws -> Data {
        return try get(href).read().get()
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
            title != firstLink?.href.removingPrefix("/") else
        {
            return nil
        }
        
        return title
    }

}

/// Creates a `Fetcher` from an archive or a single file.
///
/// This is used as a support for backward compatibility in the old parser APIs, the `Streamer`
/// implements its own algorithm for creating the leaf fetcher, with a recovery mechanism
/// to handle user password.
func makeFetcher(for url: URL) throws -> Fetcher {
    guard (try? url.checkResourceIsReachable()) == true else {
        throw Publication.OpeningError.notFound
    }
    
    do {
        return try ArchiveFetcher(url: url, password: nil, openArchive: DefaultArchiveFactory)
    } catch {
        return FileFetcher(href: "/\(url.lastPathComponent)", path: url)
    }
}
