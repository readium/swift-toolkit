//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Returns a new ``Resource`` accessing the same data but not owning them.
///
/// This is useful when you want to pass a ``Resource`` to a component which
/// might close it, but you want to keep using it after.
public extension Resource {
    func borrowed() -> Resource {
        BorrowedResource(resource: self)
    }
}

private class BorrowedResource: Resource {
    private let resource: Resource

    init(resource: Resource) {
        self.resource = resource
    }

    func close() {
        // Do nothing
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
