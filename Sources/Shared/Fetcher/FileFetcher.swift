//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Provides access to resources on the local file system.
public final class FileFetcher: Fetcher, Loggable {
    /// Reachable local paths, indexed by the exposed HREF.
    /// Sub-paths are reachable as well, to be able to access a whole directory.
    private let paths: [RelativeURL: URL]

    /// Provides access to a collection of local paths.
    public init(paths: [RelativeURL: URL]) {
        self.paths = paths.mapValues { $0.standardizedFileURL }
    }

    /// Provides access to the given local `path` at `href`.
    public convenience init(href: RelativeURL, path: URL) {
        self.init(paths: [href: path])
    }

    public func get(_ link: Link) -> Resource {
        if let linkHREF = link.uri().relativeURL {
            for (href, url) in paths {
                if linkHREF == href {
                    return FileResource(link: link, file: url)

                } else if let relativeHREF = linkHREF.relativize(href)?.path {
                    let resourceURL = url.appendingPathComponent(relativeHREF).standardizedFileURL
                    // Makes sure that the requested resource is `url` or one of its descendant.
                    if url.isParentOf(resourceURL) {
                        return FileResource(link: link, file: resourceURL)
                    }
                }
            }
        }

        return FailureResource(link: link, error: .notFound(nil))
    }

    public lazy var links: [Link] =
        paths.keys
            .sorted { $0.string < $1.string }
            .flatMap { links(at: $0) }

    private func links(at href: RelativeURL) -> [Link] {
        guard
            let path = paths[href],
            let enumerator = FileManager.default.enumerator(at: path, includingPropertiesForKeys: [.isDirectoryKey])
        else {
            return []
        }

        return ([path] + enumerator).compactMap {
            guard
                let url = $0 as? URL,
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                values.isDirectory == false
            else {
                return nil
            }

            let subPath = url.standardizedFileURL.path.removingPrefix(path.standardizedFileURL.path)
            guard let href = href.appendingPath(subPath) else {
                return nil
            }

            return Link(
                href: href.string,
                type: MediaType.of(url)?.string
            )
        }
    }

    public func close() {}
}
