//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Creates a `ContentIterator` instance for the given `resource`.
///
/// - Returns: nil if the resource format is not supported.
public typealias ResourceContentIteratorFactory =
    (_ resource: Resource, _ locator: Locator) -> ContentIterator?

public class PublicationContentIterator: ContentIterator, Loggable {

    private let publication: Publication
    private var startLocator: Locator?
    private let resourceContentIteratorFactories: [ResourceContentIteratorFactory]
    private var startIndex: Int?
    private var currentIndex: Int = 0
    private var currentIterator: ContentIterator?

    public init(publication: Publication, start: Locator?, resourceContentIteratorFactories: [ResourceContentIteratorFactory]) {
        self.publication = publication
        self.startLocator = start
        self.resourceContentIteratorFactories = resourceContentIteratorFactories

        startIndex = {
            guard
                let start = start,
                let index = publication.readingOrder.firstIndex(withHREF: start.href)
            else {
                return 0
            }
            return index
        }()
    }

    public func close() {
        currentIterator?.close()
        currentIterator = nil
    }

    public func previous() throws -> Content? {
        guard let iterator = iterator(by: -1) else {
            return nil
        }
        guard let content = try iterator.previous() else {
            currentIterator = nil
            return try previous()
        }
        return content
    }

    public func next() throws -> Content? {
        guard let iterator = iterator(by: +1) else {
            return nil
        }
        guard let content = try iterator.next() else {
            currentIterator = nil
            return try next()
        }
        return content
    }

    private func iterator(by delta: Int) -> ContentIterator? {
        if let iter = currentIterator {
            return iter
        }
        
        // For the first requested iterator, we don't want to move by the given delta.
        var delta = delta
        if let start = startIndex {
            startIndex = nil
            currentIndex = start
            delta = 0
        }
        
        guard let (newIndex, newIterator) = loadIterator(from: currentIndex, by: delta) else {
            return nil
        }
        currentIndex = newIndex
        currentIterator = newIterator
        return newIterator
    }

    private func loadIterator(from index: Int, by delta: Int) -> (index: Int, ContentIterator)? {
        let i = index + delta
        guard
            let link = publication.readingOrder.getOrNil(i),
            var locator = publication.locate(link)
        else {
            return nil
        }
        
        if let start = startLocator.pop() {
            locator = locator.copy(
                locations: { $0 = start.locations },
                text: { $0 = start.text }
            )
        } else if delta < 0 {
            locator = locator.copy(
                locations: { $0.progression = 1.0 }
            )
        }

        guard let iterator = loadIterator(at: link, locator: locator) else {
            return loadIterator(from: i, by: delta)
        }
        return (i, iterator)
    }

    private func loadIterator(at link: Link, locator: Locator) -> ContentIterator? {
        let resource = publication.get(link)
        for factory in resourceContentIteratorFactories {
            if let iterator = factory(resource, locator) {
                return iterator
            }
        }

        return nil
    }
}
