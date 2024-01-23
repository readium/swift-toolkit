//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension Publication {
    @available(*, unavailable, message: "format and formatVersion are deprecated", renamed: "init(manifest:fetcher:servicesBuilder:)")
    convenience init(manifest: Manifest, fetcher: Fetcher = EmptyFetcher(), servicesBuilder: PublicationServicesBuilder = .init(), format: Format = .unknown, formatVersion: String? = nil) {
        fatalError()
    }
}
