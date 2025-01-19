//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Implements the transformation of a Resource. It can be used, for example, to decrypt,
/// deobfuscate, inject CSS or JavaScript, correct content – e.g. adding a missing `dir="rtl"` in
/// an HTML document, pre-process – e.g. before indexing a publication's content, etc.
///
/// If the transformation doesn't apply, simply return resource unchanged.
public typealias ResourceTransformer = (_ href: AnyURL, _ resource: Resource) -> Resource

/// Transforms the resources' content of a child fetcher using a list of `ResourceTransformer`
/// functions.
public final class TransformingContainer: Container {
    private let container: Container
    private let transformers: [ResourceTransformer]

    public init(container: Container, transformers: [ResourceTransformer]) {
        self.container = container
        self.transformers = transformers
    }

    public convenience init(container: Container, transformer: @escaping ResourceTransformer) {
        self.init(container: container, transformers: [transformer])
    }

    public let sourceURL: AbsoluteURL? = nil
    public var entries: Set<AnyURL> { container.entries }

    public subscript(url: any URLConvertible) -> Resource? {
        let url = url.anyURL
        guard let resource = container[url] else {
            return nil
        }
        return transformers.reduce(resource) { resource, transformer in
            transformer(url, resource)
        }
    }
}

/// Convenient shortcuts to create a `TransformingContainer`.
public extension Container {
    func map(transform: @escaping (_ href: AnyURL, _ resource: Resource) -> Resource) -> Container {
        TransformingContainer(container: self, transformer: { transform($0, $1) })
    }
}
