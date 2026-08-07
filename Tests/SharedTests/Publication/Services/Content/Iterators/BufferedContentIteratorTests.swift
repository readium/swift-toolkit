//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

struct BufferedContentIteratorTests {
    private let elements: [ContentElement] = ["A", "B", "C", "D"].map(element(_:))

    @Test func forwardIterationPullsEachElementOnce() async throws {
        let (iter, mock) = makeIterator(elements)

        for expected in elements {
            let result = try await iter.next()
            #expect(result?.equatable() == expected.equatable())
        }
        #expect(try await iter.next() == nil)
        #expect(await mock.nextCallCount == 5)
        #expect(await mock.previousCallCount == 0)
    }

    @Test func previousIsNilFromTheBeginning() async throws {
        let (iter, _) = makeIterator(elements)
        #expect(try await iter.previous() == nil)
    }

    @Test func nextThenPreviousReturnsNil() async throws {
        // Mirrors the resource iterators' cursor invariant: after `next()`
        // returned element N, `previous()` returns element N-1.
        let (iter, _) = makeIterator(elements)
        _ = try await iter.next()
        #expect(try await iter.previous() == nil)
        let second = try await iter.next()
        #expect(second?.equatable() == elements[1].equatable())
    }

    @Test func peekingDoesNotMoveTheCursor() async throws {
        let (iter, mock) = makeIterator(elements)
        _ = try await iter.next() // A

        let peeked = try await iter.peekAfter(1)
        #expect(peeked?.equatable() == elements[1].equatable())
        #expect(await mock.nextCallCount == 2)

        // The peeked element is served from the buffer.
        let second = try await iter.next()
        #expect(second?.equatable() == elements[1].equatable())
        #expect(await mock.nextCallCount == 2)

        let before = try await iter.peekBefore(1)
        #expect(before?.equatable() == elements[0].equatable())
        #expect(await mock.previousCallCount == 0)
    }

    @Test func directionFlipIssuesCompensatingCalls() async throws {
        let (iter, mock) = makeIterator(elements)
        _ = try await iter.next() // A
        _ = try await iter.next() // B
        _ = try await iter.peekAfter(1) // C, moves the inner cursor to C
        #expect(await mock.nextCallCount == 3)

        // Served from the buffer, no inner call.
        let back = try await iter.previous()
        #expect(back?.equatable() == elements[0].equatable())
        #expect(await mock.previousCallCount == 0)

        // Walking before A: the inner cursor sits on C, so two compensating
        // `previous()` replay B and A before the final pull returns nil.
        #expect(try await iter.previous() == nil)
        #expect(await mock.previousCallCount == 3)
        #expect(await mock.nextCallCount == 3)

        // Forward again, from the buffer.
        let second = try await iter.next()
        #expect(second?.equatable() == elements[1].equatable())
        #expect(await mock.nextCallCount == 3)
    }

    @Test func peeksPastTheEndAreNil() async throws {
        let (iter, mock) = makeIterator(elements)
        for _ in elements {
            _ = try await iter.next()
        }
        #expect(try await iter.peekAfter(1) == nil)
        #expect(try await iter.peekAfter(2) == nil)
        // The end is memoized: no extra pull for the second peek.
        #expect(await mock.nextCallCount == 5)
    }

    @Test func trimmedElementsAreRefetched() async throws {
        let manyElements = (0 ..< 20).map { element("\($0)") }
        let (iter, _) = makeIterator(manyElements, capacity: 4)

        for expected in manyElements {
            let result = try await iter.next()
            #expect(result?.equatable() == expected.equatable())
        }

        // Walk all the way back: elements trimmed from the buffer are pulled
        // again from the wrapped iterator.
        var backward: [AnyEquatableContentElement] = []
        while let element = try await iter.previous() {
            backward.append(element.equatable())
        }
        #expect(backward == manyElements.dropLast().reversed().map { $0.equatable() })
    }
}

// MARK: - Helpers

private func element(_ text: String) -> TextContentElement {
    let locator = Locator(href: "res.xhtml", mediaType: .xhtml).copy(
        text: { $0 = Locator.Text(highlight: text) }
    )
    return TextContentElement(
        locator: locator,
        role: .body,
        segments: [TextContentElement.Segment(locator: locator, text: text)]
    )
}

private func makeIterator(
    _ elements: [ContentElement],
    capacity: Int = 8
) -> (BufferedContentIterator, MockContentIterator) {
    let mock = MockContentIterator(elements)
    return (BufferedContentIterator(mock, capacity: capacity), mock)
}
