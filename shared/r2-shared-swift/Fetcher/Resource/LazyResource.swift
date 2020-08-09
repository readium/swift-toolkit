//
//  LazyResource.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 09/08/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
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
    
    public var link: Link { resource.link }
    
    public var length: ResourceResult<UInt64> { resource.length }
    
    public func read(range: Range<UInt64>?) -> ResourceResult<Data> {
        return resource.read(range: range)
    }
    
    public func close() {
        if isLoaded {
            resource.close()
        }
    }
}
