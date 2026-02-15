//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public typealias ContentServiceFactory = @Sendable (PublicationServiceContext) -> ContentService?

/// Provides a way to extract the raw `Content` of a `Publication`.
public protocol ContentService: PublicationService {
    /// Creates a `Content` starting from the given `start` location.
    ///
    /// The implementation must be fast and non-blocking. Do the actual extraction inside the
    /// `Content` implementation.
    func content(from start: Locator?) -> Content?
}

/// Default implementation of `ContentService`, delegating the content parsing to `ResourceContentIteratorFactory`.
public class DefaultContentService: ContentService, @unchecked Sendable {
    private let publication: Weak<Publication>
    private let resourceContentIteratorFactories: [any ResourceContentIteratorFactory & Sendable]

    public init(publication: Weak<Publication>, resourceContentIteratorFactories: [any ResourceContentIteratorFactory & Sendable]) {
        self.publication = publication
        self.resourceContentIteratorFactories = resourceContentIteratorFactories
    }

    public static func makeFactory(resourceContentIteratorFactories: [any ResourceContentIteratorFactory & Sendable]) -> ContentServiceFactory {
        { context in
            DefaultContentService(publication: context.publication, resourceContentIteratorFactories: resourceContentIteratorFactories)
        }
    }

    public func content(from start: Locator?) -> Content? {
        guard let pub = publication() else {
            return nil
        }
        return DefaultContent(publication: pub, start: start, resourceContentIteratorFactories: resourceContentIteratorFactories)
    }

    private class DefaultContent: Content {
        let publication: Publication
        let start: Locator?
        let resourceContentIteratorFactories: [any ResourceContentIteratorFactory & Sendable]

        init(publication: Publication, start: Locator?, resourceContentIteratorFactories: [any ResourceContentIteratorFactory & Sendable]) {
            self.publication = publication
            self.start = start
            self.resourceContentIteratorFactories = resourceContentIteratorFactories
        }

        func iterator() -> ContentIterator {
            PublicationContentIterator(
                publication: publication,
                start: start,
                resourceContentIteratorFactories: resourceContentIteratorFactories
            )
        }
    }
}

// MARK: Publication Helpers

public extension Publication {
    /// Creates a [Content] starting from the given `start` location, or the beginning of the
    /// publication when missing.
    func content(from start: Locator? = nil) -> Content? {
        findService(ContentService.self)?.content(from: start)
    }
}

// MARK: PublicationServicesBuilder Helpers

public extension PublicationServicesBuilder {
    mutating func setContentServiceFactory(_ factory: ContentServiceFactory?) {
        if let factory = factory {
            set(ContentService.self, factory)
        } else {
            remove(ContentService.self)
        }
    }
}
