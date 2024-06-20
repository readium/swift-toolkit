//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Encapsulates a single ``Resource`` into a ``Container``.
public class SingleResourceContainer: Container {
    private let resource: Resource
    private let entryURL: AnyURL

    public let entries: Set<AnyURL>

    public init(resource: Resource, at entryURL: AnyURL) {
        self.resource = resource
        self.entryURL = entryURL
        entries = [entryURL]
    }

    public subscript(url: any URLConvertible) -> (any Resource)? {
        guard url.anyURL.removingQuery().removingFragment().isEquivalentTo(entryURL) else {
            return nil
        }

        return resource.borrowed()
    }

    public func close() {
        resource.close()
    }
}
