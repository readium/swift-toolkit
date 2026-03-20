//
//  Copyright 2026 Readium Foundation. All rights reserved.
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

    nonisolated var sourceURL: AbsoluteURL? {
        resource.sourceURL
    }

    func properties() async throws(ReadError) -> ResourceProperties {
        try await resource.properties()
    }

    func estimatedLength() async throws(ReadError) -> UInt64? {
        try await resource.estimatedLength()
    }

    func stream(
        range: Range<UInt64>?,
        consume: @escaping (Data) -> Void
    ) async throws(ReadError) {
        guard cacheFromOffset <= range?.lowerBound ?? 0 else {
            try await resource.stream(range: range, consume: consume)
            return
        }

        let data = try await cachedTail()
        guard let data = data else {
            try await resource.stream(range: range, consume: consume)
            return
        }

        if let range = range {
            let range = range.clampedToInt()
            let lower = Int(range.lowerBound) - Int(cacheFromOffset)
            let upper = min(lower + range.count, data.count)
            guard lower >= 0 else {
                throw .decoding("Cannot satisty requested range from the cached tail")
            }
            consume(data[lower ..< upper])
        } else {
            consume(data)
        }
    }

    private var cache: Result<Data?, ReadError>?

    private func cachedTail() async throws(ReadError) -> Data? {
        if let cache = cache {
            switch cache {
            case let .success(data): return data
            case let .failure(error): throw error
            }
        }

        let length = try await estimatedLength() ?? .max
        guard cacheFromOffset < length else {
            cache = .success(nil)
            return nil
        }

        var data = Data()
        do {
            try await resource.stream(range: cacheFromOffset ..< length) { chunk in
                data.append(chunk)
            }
            cache = .success(data)
            return data
        } catch {
            cache = .failure(error)
            throw error
        }
    }
}
