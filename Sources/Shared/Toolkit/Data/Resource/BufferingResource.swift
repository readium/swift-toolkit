//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

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
    public init(resource: Resource, bufferSize: Int = 8192) {
        precondition(bufferSize > 0)
        self.resource = resource
        buffer = Buffer(maxSize: bufferSize)
    }

    @available(*, deprecated, message: "Use an Int bufferSize instead.")
    public init(resource: Resource, bufferSize: UInt64) {
        self.init(resource: resource, bufferSize: Int(bufferSize))
    }

    public nonisolated var sourceURL: AbsoluteURL? { resource.sourceURL }

    public func properties() async -> ReadResult<ResourceProperties> {
        await resource.properties()
    }

    public nonisolated func close() {
        resource.close()
    }

    private var cachedLength: ReadResult<UInt64?>?

    public func estimatedLength() async -> ReadResult<UInt64?> {
        if cachedLength == nil {
            cachedLength = await resource.estimatedLength()
        }
        return cachedLength!
    }

    public func stream(
        range: Range<UInt64>?,
        consume: @escaping (Data) -> Void
    ) async -> ReadResult<Void> {
        guard
            // Reading the whole resource bypasses buffering to keep things simple.
            var requestedRange = range,
            let optionalLength = await estimatedLength().getOrNil(),
            let length = optionalLength
        else {
            return await resource.stream(range: range, consume: consume)
        }

        requestedRange = requestedRange.clamped(to: 0 ..< length)
        guard !requestedRange.isEmpty else {
            consume(Data())
            return .success(())
        }
        if let data = buffer.get(range: requestedRange) {
            log(.trace, "Used buffer for \(requestedRange) (\(requestedRange.count) bytes)")
            consume(data)
            return .success(())
        }

        // Calculate the readRange to cover at least buffer.maxSize bytes.
        // Adjust the start if near the end of the resource.
        var readStart = requestedRange.lowerBound
        var readEnd = requestedRange.upperBound
        let missingBytesToMatchBufferSize = buffer.maxSize - requestedRange.count
        if missingBytesToMatchBufferSize > 0 {
            readEnd = min(readEnd + UInt64(missingBytesToMatchBufferSize), length)
        }
        if readEnd - readStart < buffer.maxSize {
            readStart = UInt64(max(0, Int(readEnd) - buffer.maxSize))
        }
        let readRange = readStart ..< readEnd
        log(.trace, "Requested \(requestedRange) (\(requestedRange.count) bytes), will read range \(readRange) (\(readRange.count) bytes) of resource with length \(length)")

        // Fallback on reading the requested range from the original resource.
        return await resource.read(range: readRange)
            .flatMap { data in
                buffer.set(data, at: readRange.lowerBound)

                guard let data = data[requestedRange, offsetBy: readRange.lowerBound] else {
                    return .failure(.decoding("Cannot extract the requested range from the read range"))
                }
                consume(data)
                return .success(())
            }
    }

    private struct Buffer {
        let maxSize: Int
        private var data: Data = .init()
        private var startOffset: UInt64 = 0

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

private extension Data {
    /// Reads a sub-range of `self` after shifting the given absolute range
    /// to be relative to `self`.
    subscript(_ range: Range<UInt64>, offsetBy dataStartOffset: UInt64) -> Data? {
        let lower = Int(range.lowerBound) - Int(dataStartOffset) + startIndex
        let upper = lower + range.count
        guard lower >= 0, upper <= count else {
            return nil
        }
        assert(indices.contains(lower))
        assert(indices.contains(upper - 1))
        return self[lower ..< upper]
    }
}

public extension Resource {
    /// Wraps this resource in a `BufferingResource` to improve reading
    /// performances.
    func buffered(size: Int = 8192) -> BufferingResource {
        BufferingResource(resource: self, bufferSize: size)
    }

    @available(*, deprecated, message: "Use an Int bufferSize instead.")
    func buffered(size: UInt64) -> BufferingResource {
        buffered(size: Int(size))
    }
}
