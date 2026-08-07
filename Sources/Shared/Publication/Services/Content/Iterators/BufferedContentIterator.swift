//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Wraps a `ContentIterator` to provide random relative access to the
/// elements surrounding the last returned one, without perturbing the
/// wrapped iterator's cursor semantics.
///
/// The wrapped iterator must honor the cursor invariant documented in
/// `ContentIterator`: after `next()` returned element N, `previous()` returns
/// element N-1, and vice-versa. This class absorbs the cursor bookkeeping:
/// peeking pulls elements into a bounded buffer, and direction flips issue
/// compensating calls on the wrapped iterator to bring its cursor back in
/// sync with the buffer.
actor BufferedContentIterator {
    private let inner: ContentIterator

    /// Maximum number of elements kept in the buffer.
    private let capacity: Int

    /// Number of elements preserved around the last returned element when
    /// trimming the buffer, so that nearby peeks don't trigger new pulls.
    private let keepMargin = 2

    /// Contiguous slice of the underlying element list.
    ///
    /// Elements are addressed with stable *virtual coordinates*: the first
    /// element ever pulled forward is coordinate 0, elements pulled backward
    /// from there get negative coordinates.
    private var buffer: [ContentElement] = []

    /// Virtual coordinate of `buffer.first`.
    private var bufferStart: Int = 0

    /// Virtual coordinate of the element the wrapped iterator last returned,
    /// or `nil` if it wasn't pulled yet.
    private var innerLast: Int?

    /// Virtual coordinate of the last element returned by `next()` or
    /// `previous()`, or `nil` if no element was returned yet.
    private var lastIndex: Int?

    /// Virtual coordinate of the start of the list, when reached.
    private var startCoordinate: Int?

    /// Virtual coordinate one past the end of the list, when reached.
    private var endCoordinate: Int?

    init(_ inner: ContentIterator, capacity: Int = 8) {
        precondition(capacity >= 4)
        self.inner = inner
        self.capacity = capacity
    }

    /// Advances to the next element and returns it, or `nil` when reaching
    /// the end.
    func next() async throws -> ContentElement? {
        let target = lastIndex.map { $0 + 1 } ?? 0
        guard let element = try await element(at: target) else {
            return nil
        }
        lastIndex = target
        return element
    }

    /// Moves back to the previous element and returns it, or `nil` when
    /// reaching the beginning.
    func previous() async throws -> ContentElement? {
        let target = (lastIndex ?? 0) - 1
        guard let element = try await element(at: target) else {
            return nil
        }
        lastIndex = target
        return element
    }

    /// Returns the `offset`-th element after the last returned one, without
    /// moving the cursor. `peekAfter(1)` is the element `next()` would return.
    func peekAfter(_ offset: Int = 1) async throws -> ContentElement? {
        precondition(offset >= 1)
        return try await element(at: (lastIndex ?? -1) + offset)
    }

    /// Returns the `offset`-th element before the last returned one, without
    /// moving the cursor. `peekBefore(1)` is the element `previous()` would
    /// return.
    func peekBefore(_ offset: Int = 1) async throws -> ContentElement? {
        precondition(offset >= 1)
        return try await element(at: (lastIndex ?? 0) - offset)
    }

    /// Returns the element at the given absolute virtual `coordinate` (the
    /// first element pulled forward is coordinate 0), re-centering the buffer
    /// around it.
    ///
    /// This is an absolute-addressing alternative to the `next()`/
    /// `previous()` cursor API; the two styles should not be mixed on the
    /// same instance.
    func element(atCoordinate coordinate: Int) async throws -> ContentElement? {
        guard let element = try await element(at: coordinate) else {
            return nil
        }
        lastIndex = coordinate
        return element
    }

    // MARK: - Buffer management

    /// Returns the element at the given virtual `coordinate`, extending the
    /// buffer with pulls on the wrapped iterator when needed.
    private func element(at coordinate: Int) async throws -> ContentElement? {
        if let start = startCoordinate, coordinate < start {
            return nil
        }
        if let end = endCoordinate, coordinate >= end {
            return nil
        }

        while coordinate < bufferStart {
            guard try await extendHead() else {
                return nil
            }
        }
        while coordinate >= bufferStart + buffer.count {
            guard try await extendTail() else {
                return nil
            }
        }

        return buffer[coordinate - bufferStart]
    }

    /// Pulls one more element at the tail of the buffer.
    ///
    /// Returns `false` when the end of the list is reached.
    private func extendTail() async throws -> Bool {
        try await syncInner(toLast: bufferStart + buffer.count - 1)

        guard let element = try await inner.next() else {
            endCoordinate = bufferStart + buffer.count
            return false
        }
        buffer.append(element)
        innerLast = bufferStart + buffer.count - 1
        trim()
        return true
    }

    /// Pulls one more element at the head of the buffer.
    ///
    /// Returns `false` when the beginning of the list is reached.
    private func extendHead() async throws -> Bool {
        if innerLast != nil {
            try await syncInner(toLast: bufferStart)
        }

        guard let element = try await inner.previous() else {
            startCoordinate = bufferStart
            return false
        }
        buffer.insert(element, at: 0)
        bufferStart -= 1
        innerLast = bufferStart
        trim()
        return true
    }

    /// Moves the wrapped iterator's cursor so that its last returned element
    /// sits at the `target` coordinate, by replaying already buffered
    /// elements. These compensating calls happen after a direction flip.
    private func syncInner(toLast target: Int) async throws {
        while (innerLast ?? -1) < target {
            let expected = (innerLast ?? -1) + 1
            let element = try await inner.next()
            assertMatches(element, at: expected, call: "next()")
            innerLast = expected
        }
        while let last = innerLast, last > target {
            let expected = last - 1
            let element = try await inner.previous()
            assertMatches(element, at: expected, call: "previous()")
            innerLast = expected
        }
    }

    private func assertMatches(_ element: ContentElement?, at coordinate: Int, call: String) {
        let index = coordinate - bufferStart
        guard buffer.indices.contains(index) else {
            return
        }
        assert(
            element?.isEqualTo(buffer[index]) == true,
            "The wrapped ContentIterator does not honor the cursor invariant: a compensating \(call) returned a different element"
        )
    }

    /// Drops elements far from the last returned one to bound memory usage.
    ///
    /// Trimmed elements can be pulled again from the wrapped iterator if
    /// needed later.
    private func trim() {
        while buffer.count > capacity {
            let frontCoordinate = bufferStart
            let backCoordinate = bufferStart + buffer.count - 1

            // The wrapped cursor replays through the buffer during
            // compensation, so we never trim past it.
            let canDropFront = frontCoordinate < (innerLast ?? Int.max)
                && frontCoordinate < (lastIndex ?? Int.max) - keepMargin
            let canDropBack = backCoordinate >= (innerLast ?? Int.min)
                && backCoordinate > (lastIndex ?? Int.min) + keepMargin

            if canDropFront {
                buffer.removeFirst()
                bufferStart += 1
            } else if canDropBack {
                buffer.removeLast()
            } else {
                break
            }
        }
    }
}
