//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Creates a Resource that will always return the given `error`.
public final class FailureResource: Resource {
    private let error: ResourceError

    public init(link: Link, error: ResourceError) {
        self.link = link
        self.error = error
    }

    public let link: Link

    public let file: URL? = nil

    public var length: ResourceResult<UInt64> { .failure(error) }

    public func read(range: Range<UInt64>?) -> ResourceResult<Data> {
        .failure(error)
    }

    public func close() {}
}
