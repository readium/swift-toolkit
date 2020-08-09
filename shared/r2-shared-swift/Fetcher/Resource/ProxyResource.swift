//
//  ProxyResource.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 09/08/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// A base class for a `Resource` which acts as a proxy to another one.
///
/// Every function is delegating to the proxied resource, and subclasses should override some of
/// them.
open class ProxyResource: Resource {
    
    public let resource: Resource
    
    public init(_ resource: Resource) {
        self.resource = resource
    }
    
    open var link: Link { resource.link }
    
    open var length: ResourceResult<UInt64> { resource.length }
    
    open func read(range: Range<UInt64>?) -> ResourceResult<Data> {
        return resource.read(range: range)
    }
    
    open func close() {
        resource.close()
    }
}
