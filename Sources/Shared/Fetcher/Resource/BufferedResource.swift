//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Wraps an existing `Resource` and buffers its content.
///
/// Expensive interaction with the underlying resource is minimized, since most (smaller) requests can be satisfied by
/// accessing the buffer alone. The drawback is that some extra space is required to hold the buffer and that copying
/// takes place when filling that buffer, but this is usually outweighed by the performance benefits.
///
/// Note that this implementation is pretty limited and the benefits are only apparent when reading forward and
/// consecutively – e.g. when downloading the resource by chunks. The buffer is ignored when reading backward or far
/// ahead.
public final class BufferedResource: ProxyResource {

    public init(resource: Resource, bufferSize: UInt64 = 8192) {
        assert(bufferSize > 0)
        self.bufferSize = bufferSize
        super.init(resource)
    }

    /// Size of the buffer chunks to read.
    let bufferSize: UInt64

    /// The buffer containing the current bytes read from the wrapped `Resource`, with the range it covers.
    private var buffer: (data: Data, range: Range<UInt64>)? = nil

    private lazy var cachedLength: ResourceResult<UInt64> = resource.length

    public override func read(range: Range<UInt64>?) -> ResourceResult<Data> {
        // Reading the whole resource bypasses buffering to keep things simple.
        guard
            var requestedRange = range,
            let length = cachedLength.getOrNil()
        else {
            return super.read(range: range)
        }

        requestedRange = requestedRange.clamped(to: 0..<length)
        guard !requestedRange.isEmpty else {
            return .success(Data())
        }

        // Round up the range to be read to the next `bufferSize`, because we will buffer the excess.
        let readUpperBound = min(requestedRange.upperBound.ceilMultiple(of: bufferSize), length)
        var readRange: Range<UInt64> = requestedRange.lowerBound..<readUpperBound

        // Attempt to serve parts or all of the request using the buffer.
        if let buffer = buffer {
            // Everything already buffered?
            if buffer.range.contains(requestedRange) {
                let data = extractRange(requestedRange, in: buffer.data, startingAt: buffer.range.lowerBound)
                return .success(data)

            // Beginning of requested data is buffered?
            } else if buffer.range.contains(requestedRange.lowerBound) {
                var data = buffer.data
                let bufferStart = buffer.range.lowerBound
                readRange = buffer.range.upperBound..<readRange.upperBound

                return super.read(range: readRange).map { readData in
                    data += readData
                    // Shift the current buffer to the tail of the read data.
                    saveBuffer(from: data, range: readRange)

                    return extractRange(requestedRange, in: data, startingAt: bufferStart)
                }
            }
        }

        // Fallback on reading the requested range from the original resource.
        return super.read(range: readRange).map { data in
            saveBuffer(from: data, range: readRange)
            return data[0..<requestedRange.count]
        }
    }

    /// Keeps the last chunk of the given `data` as the buffer for next reads.
    ///
    /// - Parameters:
    ///   - data: Data read from the original resource.
    ///   - range: Range of the read data in the resource.
    private func saveBuffer(from data: Data, range: Range<UInt64>) {
        let lastChunk = Data(data.suffix(Int(bufferSize)))
        buffer = (
            data: lastChunk,
            range: (range.upperBound - UInt64(lastChunk.count))..<range.upperBound
        )
    }

    /// Reads a sub-range of the given `data` after shifting the given absolute (to the resource) ranges to be relative
    /// to `data`.
    private func extractRange(_ requestedRange: Range<UInt64>, in data: Data, startingAt dataStartOffset: UInt64) -> Data {
        let lower = (requestedRange.lowerBound - dataStartOffset)
        let upper = lower + (requestedRange.upperBound - requestedRange.lowerBound)
        assert(lower >= 0)
        assert(upper <= data.count)
        return data[lower..<upper]
    }

}

extension Resource {

    /// Wraps this resource in a `BufferedResource` to improve reading performances.
    public func buffered(size: UInt64 = 8192) -> BufferedResource {
        return BufferedResource(resource: self, bufferSize: size)
    }

}
