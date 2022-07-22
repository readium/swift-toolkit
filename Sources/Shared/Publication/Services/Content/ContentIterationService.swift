//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public typealias ContentIterationServiceFactory = (PublicationServiceContext) -> ContentIterationService?

public protocol ContentIterationService: PublicationService {
    func iterator(from start: Locator?) -> ContentIterator?
}

public extension Publication {
    var isContentIterable: Bool {
        contentIterationService != nil
    }

    func contentIterator(from start: Locator?) -> ContentIterator? {
        contentIterationService?.iterator(from: start)
    }

    private var contentIterationService: ContentIterationService? {
        findService(ContentIterationService.self)
    }
}

public extension PublicationServicesBuilder {
    mutating func setContentIterationServiceFactory(_ factory: ContentIterationServiceFactory?) {
        if let factory = factory {
            set(ContentIterationService.self, factory)
        } else {
            remove(ContentIterationService.self)
        }
    }
}

public class DefaultContentIterationService: ContentIterationService {

    public static func makeFactory(resourceContentIteratorFactories: [ResourceContentIteratorFactory]) -> (PublicationServiceContext) -> DefaultContentIterationService? {
        { context in
            DefaultContentIterationService(
                publication: context.publication,
                resourceContentIteratorFactories: resourceContentIteratorFactories
            )
        }
    }

    private let publication: Weak<Publication>
    private let resourceContentIteratorFactories: [ResourceContentIteratorFactory]

    public init(
        publication: Weak<Publication>,
        resourceContentIteratorFactories: [ResourceContentIteratorFactory]
    ) {
        self.publication = publication
        self.resourceContentIteratorFactories = resourceContentIteratorFactories
    }

    public func iterator(from start: Locator?) -> ContentIterator? {
        guard let publication = publication() else {
            return nil
        }
        return PublicationContentIterator(
            publication: publication,
            start: start,
            resourceContentIteratorFactories: resourceContentIteratorFactories
        )
    }
}