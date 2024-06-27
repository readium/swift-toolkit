//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Acts as a proxy to an actual resource by handling read access.
public protocol Resource: Streamable {
    /// URL locating this resource, if any.
    var sourceURL: AbsoluteURL? { get }

    /// Properties associated to the resource.
    ///
    /// This is opened for extensions.
    func properties() async -> ReadResult<ResourceProperties>
}

public extension Resource {
    @available(*, unavailable, message: "Not available anymore in a Resource")
    var link: Link { fatalError() }

    @available(*, unavailable, message: "Use the async variant")
    var length: ResourceResult<UInt64> { fatalError() }

    @available(*, deprecated, renamed: "sourceURL")
    var file: FileURL? { fatalError() }

    @available(*, unavailable, message: "Use the async variant")
    func read(range: Range<UInt64>?) -> ResourceResult<Data> { fatalError() }

    @available(*, deprecated, message: "Use the async variant")
    func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void, completion: @escaping (ReadResult<Void>) -> Void) -> Cancellable {
        fatalError()
    }
}

/// Errors occurring while accessing a resource.
@available(*, unavailable, renamed: "ReadError")
public typealias ResourceError = ReadError

@available(*, unavailable, renamed: "ReadResult")
public typealias ResourceResult<Success> = ReadResult<Success>
