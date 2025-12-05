//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension Manifest {
    /// Resolves the HREFs in the ``Manifest`` to the link with `rel="self"`.
    mutating func normalizeHREFsToSelf() throws {
        guard let base = linkWithRel(.self)?.url() else {
            return
        }

        try normalizeHREFs(to: base)
    }

    /// Resolves the HREFs in the ``Manifest`` to the given `baseURL`.
    mutating func normalizeHREFs<T: URLConvertible>(to baseURL: T) throws {
        try transform(HREFNormalizer(baseURL: baseURL))
    }
}

public extension Link {
    /// Resolves the HREFs in the ``Link`` to the given `baseURL`.
    mutating func normalizeHREFs<T: URLConvertible>(to baseURL: T?) throws {
        guard let baseURL = baseURL else {
            return
        }
        try transform(HREFNormalizer(baseURL: baseURL))
    }
}

private struct HREFNormalizer: ManifestTransformer, Loggable {
    let baseURL: AnyURL

    init<T: URLConvertible>(baseURL: T) {
        self.baseURL = baseURL.anyURL
    }

    func transform(link: inout Link) throws {
        guard !link.templated else {
            log(.warning, "Cannot safely resolve a URI template to a base URL before expanding it: \(link.href)")
            return
        }

        link.href = link.url(relativeTo: baseURL).string
    }
}
