//
//  CachingResource.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 09/08/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
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
        return data.map { data in
            let length = UInt64(data.count)
            if let range = range?.clamped(to: 0..<length) {
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
        return (self is CachingResource) ? self
            : CachingResource(resource: self)
    }
    
}
