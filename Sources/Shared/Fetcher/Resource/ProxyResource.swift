//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
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

    open var file: URL? { resource.file }

    open var link: Link { resource.link }

    open var length: ResourceResult<UInt64> { resource.length }

    open func read(range: Range<UInt64>?) -> ResourceResult<Data> {
        resource.read(range: range)
    }

    open func close() {
        resource.close()
    }
}
