//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public struct Content: Equatable {
    public let locator: Locator
    public let data: Data

    public var extras: [String: Any] {
        get { extrasJSON.json }
        set { extrasJSON = JSONDictionary(newValue) ?? JSONDictionary() }
    }
    // Trick to keep the struct equatable despite [String: Any]
    private var extrasJSON: JSONDictionary

    public init(locator: Locator, data: Data, extras: [String: Any] = [:]) {
        self.locator = locator
        self.data = data
        self.extrasJSON = JSONDictionary(extras) ?? JSONDictionary()
    }

    public enum Data: Equatable {
        case audio(target: Link)
        case image(target: Link, description: String?)
        case text(spans: TextSpan, style: TextStyle)
    }

    public enum TextStyle: Equatable {
        case heading(level: Int)
        case body
        case callout
        case caption
        case footnote
        case quote
        case listItem
    }

    public struct TextSpan: Equatable {
        let locator: Locator
        let language: String?
        let text: String
    }
}

public protocol ContentIterator: AnyObject {
    @discardableResult
    func previous(completion: @escaping (Result<Content?, Error>) -> Void) -> Cancellable

    @discardableResult
    func next(completion: @escaping (Result<Content?, Error>) -> Void) -> Cancellable

    func close()
}


/// Creates a `ContentIterator` instance for the given `resource`.
///
/// - Returns: nil if the resource format is not supported.
typealias ResourceContentIteratorFactory =
    (_ resource: Resource, _ locator: Locator) -> ContentIterator?

class PublicationContentIterator: ContentIterator {

    private let publication: Publication
    private var startLocator: Locator?
    private let resourceContentIteratorFactories: [ResourceContentIteratorFactory]
    private let startIndex: Int
    private var currentIndex: Int
    private var currentIterator: ContentIterator?

    private let queue = DispatchQueue(label: "org.readium.shared.PublicationContentIterator")

    init(publication: Publication, start: Locator?, resourceContentIteratorFactories: [ResourceContentIteratorFactory]) {
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

        currentIndex = startIndex
    }

    func previous(completion: @escaping (Result<Content?, Error>) -> Void) -> Cancellable {
        return CancellableObject()
    }

    func next(completion: @escaping (Result<Content?, Error>) -> Void) -> Cancellable {
        let cancellable = MediatorCancellable()

        func finish(_ result: Result<Content?, Error>) {
            guard !cancellable.isCancelled else {
                return
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }

        queue.async { [self] in
            guard let iterator = iterator(by: +1) else {
                finish(.success(nil))
                return
            }
            guard !cancellable.isCancelled else {
                return
            }

            iterator
                .next { result in
                    switch result {
                    case .success(let content):
                        if let content = content {
                            finish(.success(content))
                        } else {
                            next(completion: completion)
                                .mediated(by: cancellable)
                        }
                    case .failure(let error):
                        finish(.failure(error))
                    }
                }
                .mediated(by: cancellable)
        }

        return cancellable
    }

    func iterator(by delta: Int) -> ContentIterator? {
        if let iter = currentIterator {
            return iter
        }
        guard let (newIndex, newIterator) = loadIterator(from: currentIndex, by: delta) else {
            return nil
        }
        currentIndex = newIndex
        currentIterator = newIterator
        return newIterator
    }

    func loadIterator(from index: Int, by delta: Int) -> (index: Int, ContentIterator)? {
        let i = index + delta
        guard publication.readingOrder.indices.contains(i)  else {
            return nil
        }
        guard let iterator = loadIterator(at: i) else {
            return loadIterator(from: i, by: delta)
        }
        return (i, iterator)
    }

    func loadIterator(at index: Int) -> ContentIterator? {
        let link = publication.readingOrder[index]
        guard var locator = publication.locate(link) else {
            return nil
        }

        if let start = startLocator.pop() {
            locator = locator.copy(
                locations: { $0 = start.locations },
                text: { $0 = start.text }
            )
        }

        let resource = publication.get(link)
        for factory in resourceContentIteratorFactories {
            if let iterator = factory(resource, locator) {
                return iterator
            }
        }

        return nil
    }

    func close() {
        currentIterator?.close()
        currentIterator = nil
    }
}

public extension Optional {
    mutating func pop() -> Wrapped? {
        let res = self
        self = nil
        return res
    }
}