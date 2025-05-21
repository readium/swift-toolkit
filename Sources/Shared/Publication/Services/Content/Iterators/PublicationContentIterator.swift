//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public protocol ResourceContentIteratorFactory {
    /// Creates a `ContentIterator` instance for the `resource`, starting from
    /// the given `locator`.
    ///
    /// - Returns: nil if the resource format is not supported.
    func make(
        publication: Publication,
        readingOrderIndex: Int,
        resource: Resource,
        locator: Locator
    ) -> ContentIterator?
}

/// A composite [Content.Iterator] which iterates through a whole [publication] and delegates the
/// iteration inside a given resource to media type-specific iterators.
public class PublicationContentIterator: ContentIterator, Loggable {
    /// `ContentIterator` for a resource, associated with its index in the reading order.
    private typealias IndexedIterator = (index: Int, iterator: ContentIterator)

    private enum Direction: Int {
        case forward = 1
        case backward = -1
    }

    private let publication: Publication
    private var startLocator: Locator?
    private var _currentIterator: IndexedIterator?

    /// List of `ResourceContentIteratorFactory` which will be used to create the iterator for each resource. The
    /// factories are tried in order until there's a match.
    private let resourceContentIteratorFactories: [ResourceContentIteratorFactory]

    public init(publication: Publication, start: Locator?, resourceContentIteratorFactories: [ResourceContentIteratorFactory]) {
        self.publication = publication
        startLocator = start
        self.resourceContentIteratorFactories = resourceContentIteratorFactories
    }

    public func previous() async throws -> ContentElement? {
        try await next(.backward)
    }

    public func next() async throws -> ContentElement? {
        try await next(.forward)
    }

    private func next(_ direction: Direction) async throws -> ContentElement? {
        guard let iterator = await currentIterator() else {
            return nil
        }

        let content: ContentElement? = try await {
            switch direction {
            case .forward:
                return try await iterator.iterator.next()
            case .backward:
                return try await iterator.iterator.previous()
            }
        }()
        guard content != nil else {
            guard let nextIterator = await nextIterator(direction, fromIndex: iterator.index) else {
                return nil
            }
            _currentIterator = nextIterator
            return try await next(direction)
        }

        return content
    }

    /// Returns the `ContentIterator` for the current `Resource` in the reading order.
    private func currentIterator() async -> IndexedIterator? {
        if _currentIterator == nil {
            _currentIterator = await initialIterator()
        }
        return _currentIterator
    }

    /// Returns the first iterator starting at `startLocator` or the beginning of the publication.
    private func initialIterator() async -> IndexedIterator? {
        let index = startLocator.flatMap { publication.readingOrder.firstIndexWithHREF($0.href) } ?? 0
        let location = startLocator.orProgression(0.0)

        if let iterator = await loadIterator(at: index, location: location) {
            return iterator
        } else {
            return await nextIterator(.forward, fromIndex: index)
        }
    }

    /// Returns the next resource iterator in the given `direction`, starting from `fromIndex`.
    private func nextIterator(_ direction: Direction, fromIndex: Int) async -> IndexedIterator? {
        let index = fromIndex + direction.rawValue
        guard publication.readingOrder.indices.contains(index) else {
            return nil
        }

        let progression: Double = {
            switch direction {
            case .forward:
                return 0.0
            case .backward:
                return 1.0
            }
        }()

        if let iterator = await loadIterator(at: index, location: .progression(progression)) {
            return iterator
        } else {
            return await nextIterator(direction, fromIndex: index)
        }
    }

    /// Loads the iterator at the given `index` in the reading order.
    ///
    /// The `location` will be used to compute the starting `Locator` for the iterator.
    private func loadIterator(at index: Int, location: LocatorOrProgression) async -> IndexedIterator? {
        let link = publication.readingOrder[index]
        guard
            let resource = publication.get(link),
            let locator = await location.toLocator(to: link, in: publication)
        else {
            return nil
        }

        return resourceContentIteratorFactories
            .first { factory in
                factory.make(
                    publication: publication,
                    readingOrderIndex: index,
                    resource: resource,
                    locator: locator
                )
            }
            .map { IndexedIterator(index: index, iterator: $0) }
    }
}

/// Represents either a full `Locator`, or a progression percentage in a resource.
private enum LocatorOrProgression {
    case locator(Locator)
    case progression(Double)

    func toLocator(to link: Link, in publication: Publication) async -> Locator? {
        switch self {
        case let .locator(locator):
            return locator
        case let .progression(progression):
            return await publication.locate(link)?.copy(locations: { $0.progression = progression })
        }
    }
}

private extension Optional where Wrapped == Locator {
    /// Returns this locator if not null, or the given `progression` as a fallback.
    func orProgression(_ progression: Double) -> LocatorOrProgression {
        if case let .some(locator) = self {
            return .locator(locator)
        } else {
            return .progression(progression)
        }
    }
}
