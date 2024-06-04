//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Provides access to resources on the local file system.
public final class FileFetcher: Fetcher, Loggable {
    /// Reachable local paths, indexed by the exposed HREF.
    /// Sub-files are reachable as well, to be able to access a whole directory.
    private let paths: [RelativeURL: FileURL]

    /// Provides access to a collection of local paths.
    public init(paths: [RelativeURL: FileURL]) {
        self.paths = paths
    }

    /// Provides access to the given local `file` at `href`.
    public convenience init(href: RelativeURL, file: FileURL) {
        self.init(paths: [href: file])
    }

    public func get(_ link: Link) -> Resource {
        if let linkHREF = try? link.url().relativeURL {
            for (href, url) in paths {
                if linkHREF == href {
                    return FileResource(link: link, file: url)

                } else if let relativeHREF = href.relativize(linkHREF)?.path {
                    let resourceURL = url.appendingPath(relativeHREF, isDirectory: false)
                    // Makes sure that the requested resource is `url` or one of its descendant.
                    if url.isParent(of: resourceURL) {
                        return FileResource(link: link, file: resourceURL)
                    }
                }
            }
        }

        log(.warning, "Unable to create FileResource from link \(link)")
        return FailureResource(link: link, error: .notFound(nil))
    }

    public lazy var links: [Link] =
        paths.keys
            .sorted { $0.string < $1.string }
            .flatMap { links(at: $0) }

    private func links(at href: RelativeURL) -> [Link] {
        guard
            let path = paths[href],
            let enumerator = FileManager.default.enumerator(at: path.url, includingPropertiesForKeys: [.isDirectoryKey])
        else {
            return []
        }

        return ([path.url] + enumerator).compactMap {
            guard
                let url = $0 as? URL,
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                values.isDirectory == false
            else {
                return nil
            }

            let subPath = url.standardizedFileURL.path.removingPrefix(path.path)
            return Link(
                href: href.appendingPath(subPath, isDirectory: false).string,
                type: FileURL(url: url).flatMap { MediaType.of($0)?.string }
            )
        }
    }

    public func close() {}
}
