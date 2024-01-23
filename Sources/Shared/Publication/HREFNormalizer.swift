//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension Manifest {
    /// Resolves the HREFs in the ``Manifest`` to the link with `rel="self"`.
    mutating func normalizeHREFsToSelf() {
        guard let base = link(withRel: .self)?.url() else {
            return
        }

        normalizeHREFs(to: base)
    }

    /// Resolves the HREFs in the ``Manifest`` to the given `baseURL`.
    mutating func normalizeHREFs<T: URLConvertible>(to baseURL: T) {
        transform(HREFNormalizer(baseURL: baseURL))
    }
}

public extension Link {
    /// Resolves the HREFs in the ``Link`` to the given `baseURL`.
    mutating func normalizeHREFs<T: URLConvertible>(to baseURL: T?) {
        guard let baseURL = baseURL else {
            return
        }
        transform(HREFNormalizer(baseURL: baseURL))
    }
}

private struct HREFNormalizer: ManifestTransformer, Loggable {
    let baseURL: AnyURL

    init<T: URLConvertible>(baseURL: T) {
        self.baseURL = baseURL.anyURL
    }

    func transform(link: inout Link) {
        guard !link.templated else {
            log(.warning, "Cannot safely resolve a URI template to a base URL before expanding it: \(link.href)")
            return
        }

        link.href = link.url(relativeTo: baseURL).string
    }
}
