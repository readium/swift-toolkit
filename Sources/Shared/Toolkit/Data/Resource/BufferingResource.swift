//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Wraps an existing `Resource` and buffers its content.
///
/// Expensive interaction with the underlying resource is minimized, since most
/// (smaller) requests can be satisfied by accessing the buffer alone. The
/// drawback is that some extra space is required to hold the buffer and that
/// copying takes place when filling that buffer, but this is usually
/// outweighed by the performance benefits.
///
/// Note that this implementation is pretty limited and the benefits are only
/// apparent when reading forward and consecutively – e.g. when downloading the
/// resource by chunks. The buffer is ignored when reading backward or far
/// ahead.
public actor BufferingResource: Resource, Loggable {
    private nonisolated let resource: Resource

    /// The buffer containing the current bytes read from the wrapped
    /// `Resource`, with the range it covers.
    private var buffer: Buffer

    /// - Parameter bufferSize: Size of the buffer chunks to read.
    public init(resource: Resource, bufferSize: Int = 256 * 1024) {
        precondition(bufferSize > 0)
        self.resource = resource
        buffer = Buffer(maxSize: bufferSize)
    }

    @available(*, deprecated, message: "Use an Int bufferSize instead.")
    public init(resource: Resource, bufferSize: UInt64) {
        self.init(resource: resource, bufferSize: Int(bufferSize))
    }

    public nonisolated var sourceURL: AbsoluteURL? {
        resource.sourceURL
    }

    public func properties() async -> ReadResult<ResourceProperties> {
        await resource.properties()
    }

    private var cachedLength: ReadResult<UInt64?>?

    public func estimatedLength() async -> ReadResult<UInt64?> {
        if let cachedLength {
            return cachedLength
        }
        let result = await resource.estimatedLength()
        if case .success = result {
            cachedLength = result
        }
        return result
    }

    public func stream(
        range: Range<UInt64>?,
        consume: @escaping @Sendable (Data) -> Void
    ) async -> ReadResult<Void> {
        // Reading the whole resource bypasses buffering to keep things simple.
        guard let requestedRange = range, !requestedRange.isEmpty else {
            return await resource.stream(range: range, consume: consume)
        }

        // Serve from the buffer if the request is fully covered.
        if let data = buffer.get(range: requestedRange) {
            consume(data)
            return .success(())
        }

        // Read ahead from the request start to fill the buffer.
        let readAheadEnd = requestedRange.lowerBound + UInt64(buffer.maxSize)
        let readRange = requestedRange.lowerBound ..< max(requestedRange.upperBound, readAheadEnd)

        // Range that will actually need to be read from the original resource,
        // after reusing any overlap with the current buffer.
        var fetchRange = readRange
        var prefixData = Data()

        // Checks if the beginning of the range to read is already buffered.
        // This is an optimization particularly useful with LCP, where we need
        // to go backward for every read to get the previous block of data.
        if
            fetchRange.lowerBound < buffer.range.upperBound,
            fetchRange.upperBound > buffer.range.upperBound,
            let dataPrefix = buffer.get(range: fetchRange.lowerBound ..< buffer.range.upperBound)
        {
            prefixData = Data(dataPrefix)
            fetchRange = buffer.range.upperBound ..< fetchRange.upperBound
        }

        // Read from the original resource using stream to avoid materializing
        // more than needed.
        let result = await resource.read(range: fetchRange)
        
        let newData: Data
        switch result {
        case .success(let d):
            newData = d
        case .failure(let error):
            return .failure(error)
        }

        var data = prefixData
        data.append(newData)

        buffer.set(data, at: readRange.lowerBound)

        let end = min(Int(requestedRange.count), data.count)
        if end > 0 {
            consume(data[0 ..< end])
        }
        return .success(())
    }

    private struct Buffer {
        let maxSize: Int
        private var data: Data = .init()
        private var startOffset: UInt64 = 0

        var range: Range<UInt64> {
            startOffset ..< (startOffset + UInt64(data.count))
        }

        init(maxSize: Int) {
            self.maxSize = maxSize
        }

        mutating func set(_ data: Data, at offset: UInt64) {
            var data = data
            var offset = offset

            // Truncates the beginning of the data to maxSize.
            if data.count > maxSize {
                offset += UInt64(data.count - maxSize)
                data = Data(data.suffix(maxSize))
            }

            self.data = data
            startOffset = offset
        }

        func get(range: Range<UInt64>) -> Data? {
            data[range, offsetBy: startOffset]
        }
    }
}

public extension Resource {
    /// Wraps this resource in a `BufferingResource` to improve reading
    /// performances.
    func buffered() -> BufferingResource {
        BufferingResource(resource: self)
    }

    /// Wraps this resource in a `BufferingResource` to improve reading
    /// performances.
    func buffered(size: Int) -> BufferingResource {
        BufferingResource(resource: self, bufferSize: size)
    }

    @available(*, deprecated, message: "Use an Int bufferSize instead.")
    func buffered(size: UInt64) -> BufferingResource {
        buffered(size: Int(size))
    }
}
