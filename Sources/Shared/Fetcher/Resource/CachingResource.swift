//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Caches the members of `resource` on first access, to optimize subsequent accesses.
///
/// This can be useful when reading `resource` is expensive.
///
/// **Warning**: Bytes are read and cached entirely the first time, even if only a `range` is
/// requested. So this is not appropriate for large resources.
public final class CachingResource: Resource {
    private let resource: Resource

    private var isDataLoaded = false
    private lazy var data: ResourceResult<Data> = {
        isDataLoaded = true
        return resource.read()
    }()

    init(resource: Resource) {
        self.resource = resource
    }

    public lazy var file: URL? = resource.file

    public lazy var link: Link = resource.link

    public lazy var length: ResourceResult<UInt64> = isDataLoaded
        ? data.map { UInt64($0.count) }
        : resource.length

    public func read(range: Range<UInt64>?) -> ResourceResult<Data> {
        data.map { data in
            let length = UInt64(data.count)
            if let range = range?.clamped(to: 0 ..< length) {
                return data[range]
            } else {
                return data
            }
        }
    }

    public func close() {
        resource.close()
    }
}

public extension Resource {
    /// Creates a cached resource wrapping this resource.
    func cached() -> Resource {
        (self is CachingResource) ? self
            : CachingResource(resource: self)
    }
}
