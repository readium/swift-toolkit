//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Creates a Resource that will always return the given `error`.
public final class FailureResource: Resource, Sendable {
    private let error: ReadError

    public let sourceURL: AbsoluteURL?

    public init(error: ReadError, sourceURL: AbsoluteURL? = nil) {
        self.error = error
        self.sourceURL = sourceURL
    }

    public func estimatedLength() async throws(ReadError) -> UInt64? {
        throw error
    }

    public func properties() async throws(ReadError) -> ResourceProperties {
        throw error
    }

    public func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async throws(ReadError) {
        throw error
    }
}

public extension Resource where Self == FailureResource {
    static func failure(_ error: ReadError, sourceURL: AbsoluteURL? = nil) -> FailureResource {
        FailureResource(error: error)
    }
}
