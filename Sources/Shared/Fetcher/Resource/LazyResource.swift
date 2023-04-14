//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Wraps a `Resource` which will be created only when first accessing one of its members.
public final class LazyResource: Resource {
    private let factory: () -> Resource

    private var isLoaded = false

    private lazy var resource: Resource = {
        isLoaded = true
        return factory()
    }()

    public init(factory: @escaping () -> Resource) {
        self.factory = factory
    }

    public var file: URL? { resource.file }

    public var link: Link { resource.link }

    public var length: ResourceResult<UInt64> { resource.length }

    public func read(range: Range<UInt64>?) -> ResourceResult<Data> {
        resource.read(range: range)
    }

    public func close() {
        if isLoaded {
            resource.close()
        }
    }
}
