//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Caches in memory the tail of the given `resource`, starting from
/// `cacheFromOffset`.
actor TailCachingResource: Resource, Loggable {
    private nonisolated let resource: Resource
    private let cacheFromOffset: UInt64

    /// Coalesce concurrent requests into a single Task
    private var cacheTask: Task<ReadResult<Data?>, Never>?

    init(resource: Resource, cacheFromOffset: UInt64) {
        self.resource = resource
        self.cacheFromOffset = cacheFromOffset
    }

    nonisolated var sourceURL: AbsoluteURL? {
        resource.sourceURL
    }

    func properties() async -> ReadResult<ResourceProperties> {
        await resource.properties()
    }

    func estimatedLength() async -> ReadResult<UInt64?> {
        await resource.estimatedLength()
    }

    func stream(
        range: Range<UInt64>?,
        consume: @escaping @Sendable (Data) -> Void
    ) async -> ReadResult<Void> {
        // Default to a full range if none provided
        let requestedRange = range ?? 0 ..< UInt64.max

        // If the request starts before our cache offset, we can't fulfill it from cache.
        guard cacheFromOffset <= requestedRange.lowerBound else {
            return await resource.stream(range: range, consume: consume)
        }

        let tailResult = await cachedTail()

        switch tailResult {
        case let .failure(error):
            return .failure(error)

        case let .success(data):
            guard let data = data else {
                // Cache was empty or offset was out of bounds; fallback to resource.
                return await resource.stream(range: range, consume: consume)
            }

            // Safe UInt64 arithmetic to map file offsets to local buffer indices
            let lowerBound64 = requestedRange.lowerBound - cacheFromOffset

            guard lowerBound64 < UInt64(data.count) else {
                return .success(()) // Requested range is beyond actual resource end
            }

            let requestedCount = requestedRange.upperBound - requestedRange.lowerBound
            let availableCount = UInt64(data.count) - lowerBound64

            // Only convert to Int once we are clamped to the size of 'Data'
            let countToConsume = Int(min(requestedCount, availableCount))
            let lower = Int(lowerBound64)

            if countToConsume > 0 {
                consume(data[lower ..< (lower + countToConsume)])
            }

            return .success(())
        }
    }

    private func cachedTail() async -> ReadResult<Data?> {
        if let existingTask = cacheTask {
            return await existingTask.value
        }

        let task = Task<ReadResult<Data?>, Never> {
            let lengthResult = await estimatedLength()

            switch lengthResult {
            case let .failure(error):
                return .failure(error)

            case let .success(length):
                let length = length ?? .max
                guard cacheFromOffset < length else {
                    return .success(nil)
                }

                // Bridge the streaming closure to an AsyncStream for thread-safe collection
                let (stream, continuation) = AsyncStream<Data>.makeStream()

                let streamTask = Task {
                    let result = await resource.stream(range: cacheFromOffset ..< length) { chunk in
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                    return result
                }

                var accumulatedData = Data()
                for await chunk in stream {
                    accumulatedData.append(chunk)
                }

                let finalResult = await streamTask.value
                return finalResult.map { _ in accumulatedData }
            }
        }

        cacheTask = task
        return await task.value
    }
}
