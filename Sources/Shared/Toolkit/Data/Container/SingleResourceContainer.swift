//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Encapsulates a single ``Resource`` into a ``Container``.
public class SingleResourceContainer: Container {
    public let entry: AnyURL
    private let resource: Resource

    public var sourceURL: AbsoluteURL? { resource.sourceURL }
    public var entries: Set<AnyURL> { [entry] }

    public init(resource: Resource, at entry: AnyURL) {
        self.resource = resource
        self.entry = entry
    }

    public subscript(url: any URLConvertible) -> (any Resource)? {
        guard url.anyURL.removingQuery().removingFragment().isEquivalentTo(entry) else {
            return nil
        }

        return resource
    }
}
