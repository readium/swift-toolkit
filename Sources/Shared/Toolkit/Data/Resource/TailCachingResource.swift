//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Caches in memory the tail of the given `resource`, starting from
/// `cacheFromOffset`.
///
/// This is useful if the caller needs to often read the end of the resource,
/// for example to read the Central Directory in a ZIP file.
actor TailCachingResource: Resource, Loggable {
    private nonisolated let resource: Resource
    private let cacheFromOffset: UInt64

    init(resource: Resource, cacheFromOffset: UInt64) {
        self.resource = resource
        self.cacheFromOffset = cacheFromOffset
    }

    nonisolated var sourceURL: AbsoluteURL? { resource.sourceURL }

    func properties() async -> ReadResult<ResourceProperties> {
        await resource.properties()
    }

    func estimatedLength() async -> ReadResult<UInt64?> {
        await resource.estimatedLength()
    }

    func stream(
        range: Range<UInt64>?,
        consume: @escaping (Data) -> Void
    ) async -> ReadResult<Void> {
        guard cacheFromOffset <= range?.lowerBound ?? 0 else {
            return await resource.stream(range: range, consume: consume)
        }

        return await cachedTail()
            .asyncFlatMap { data in
                guard let data = data else {
                    return await resource.stream(range: range, consume: consume)
                }

                if let range = range {
                    let range = range.clampedToInt()
                    let lower = Int(range.lowerBound) - Int(cacheFromOffset)
                    let upper = min(lower + range.count, data.count)
                    guard lower >= 0 else {
                        return .failure(.decoding("Cannot satisty requested range from the cached tail"))
                    }
                    consume(data[lower ..< upper])
                } else {
                    consume(data)
                }

                return .success(())
            }
    }

    private var cache: ReadResult<Data?>? = nil

    private func cachedTail() async -> ReadResult<Data?> {
        if let cache = cache {
            return cache
        }

        return await estimatedLength()
            .asyncFlatMap { length in
                let length = length ?? .max
                guard cacheFromOffset < length else {
                    cache = .success(nil)
                    return cache!
                }

                var data = Data()
                cache = await resource.stream(range: cacheFromOffset ..< length) { chunk in
                    data.append(chunk)
                }.map { data }

                return cache!
            }
    }
}
