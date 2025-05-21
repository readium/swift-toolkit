//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Creates a Resource that will always return the given `error`.
public final class FailureResource: Resource {
    private let error: ReadError

    public let sourceURL: AbsoluteURL?

    public init(error: ReadError, sourceURL: AbsoluteURL? = nil) {
        self.error = error
        self.sourceURL = sourceURL
    }

    public func estimatedLength() async -> ReadResult<UInt64?> {
        .failure(error)
    }

    public func properties() async -> ReadResult<ResourceProperties> {
        .failure(error)
    }

    public func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async -> ReadResult<Void> {
        .failure(error)
    }
}

public extension Resource where Self == FailureResource {
    static func failure(_ error: ReadError, sourceURL: AbsoluteURL? = nil) -> FailureResource {
        FailureResource(error: error)
    }
}
