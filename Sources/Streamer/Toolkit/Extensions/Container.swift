//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

extension SingleResourceContainer {
    /// Historically, the reading order of a standalone file contained a single
    /// link with the HREF "/$assetName". This was fragile if the asset named
    /// changed, or was different on other devices. To avoid this, we now use a
    /// single link with the HREF "publication.extension".
    convenience init(publication: ResourceAsset) {
        var filename = "publication"
        if let fileExtension = publication.format.fileExtension {
            filename = fileExtension.appendedToFilename(filename)
        }

        self.init(resource: publication.resource, at: AnyURL(string: filename)!)
    }
}

extension Container {
    /// Returns the data of a resource at given `href`.
    func readData<T: URLConvertible>(at href: T) async throws -> Data? {
        guard let resource = self[href] else {
            return nil
        }
        return try await resource.read().get()
    }

    func sniffFormats(
        using assetRetriever: AssetRetriever,
        ignoring: (AnyURL) -> Bool
    ) async -> Result<[AnyURL: Format], ReadError> {
        let urls = entries.filter { !ignoring($0) }
        var entries = [AnyURL: Format]()
        for url in urls {
            guard let resource = self[url] else {
                continue
            }

            switch await assetRetriever.sniffFormat(of: resource) {
            case let .success(format):
                entries[url] = format
            case let .failure(error):
                switch error {
                case .formatNotSupported:
                    break
                case let .reading(error):
                    return .failure(error)
                }
            }
        }

        return .success(entries)
    }

    /// Guesses a publication title from a list of resource HREFs.
    ///
    /// If the HREFs contain a single root directory, we assume it is the
    /// title. This is often the case for example with CBZ files.
    func guessTitle(ignoring: (AnyURL) -> Bool = { _ in false }) -> String? {
        var title: String?

        for url in entries {
            if ignoring(url) {
                continue
            }
            let segments = url.pathSegments
            guard segments.count > 1, title == nil || title == segments.first else {
                return nil
            }
            title = segments.first
        }

        return title
    }
}
