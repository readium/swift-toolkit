//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Returns a new ``Resource`` accessing the same data but not owning it.
///
/// This is useful when you want to pass a ``Resource`` to a component which
/// might close it, but you want to keep using it after.
public extension Resource {
    @available(*, deprecated, message: "Resources are closed on deallocation now.")
    func borrowed() -> Resource {
        BorrowedResource(resource: self)
    }
}

@available(*, deprecated, message: "Resources are closed on deallocation now.")
private class BorrowedResource: Resource {
    private let resource: Resource

    init(resource: Resource) {
        self.resource = resource
    }

    var sourceURL: AbsoluteURL? {
        resource.sourceURL
    }

    func estimatedLength() async -> ReadResult<UInt64?> {
        await resource.estimatedLength()
    }

    func properties() async -> ReadResult<ResourceProperties> {
        await resource.properties()
    }

    func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async -> ReadResult<Void> {
        await resource.stream(range: range, consume: consume)
    }
}
