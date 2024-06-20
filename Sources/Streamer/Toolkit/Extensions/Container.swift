//
//  Copyright 2024 Readium Foundation. All rights reserved.
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
            filename = fileExtension.appendToFilename(filename)
        }

        self.init(resource: publication.resource, at: AnyURL(string: filename)!)
    }
}

extension AssetRetriever {
    func sniffContainerEntries(
        container: Container,
        ignoring: (AnyURL) -> Bool
    ) async -> Result<[AnyURL: Format], ReadError> {
        let urls = container.entries.filter { !ignoring($0) }
        var entries = [AnyURL: Format]()
        for url in urls {
            guard let resource = container[url] else {
                continue
            }
            defer { resource.close() }

            switch await sniffFormat(of: resource) {
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
    }
}
