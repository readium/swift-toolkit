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

    nonisolated var sourceURL: AbsoluteURL? { resource.sourceURL }

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
        guard cacheFromOffset <= range?.lowerBound ?? 0 else {
            return await resource.stream(range: range, consume: consume)
        }
        
        let tailResult = await cachedTail()

        switch tailResult {
            case .failure(let error):
                return .failure(error)
                
            case .success(let data):
                guard let data = data else {
                    return await resource.stream(range: range, consume: consume)
                }

                if let range = range {
                    let range = range.clampedToInt()
                    let lower = Int(range.lowerBound) - Int(cacheFromOffset)
                    let upper = min(lower + range.count, data.count)
                    
                    guard lower >= 0 else {
                        return .failure(.decoding("Cannot satisfy requested range from the cached tail"))
                    }
                    
                    if lower < upper {
                        consume(data[lower ..< upper])
                    }
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

        let lengthResult = await estimatedLength()
        
        switch lengthResult {
        case .failure(let error):
            return .failure(error)
            
        case .success(let length):
            let length = length ?? .max
            guard cacheFromOffset < length else {
                let result: ReadResult<Data?> = .success(nil)
                cache = result
                return result
            }

            let buffer = ThreadSafeBuffer()

            let streamResult = await resource.stream(range: cacheFromOffset ..< length) { chunk in
                buffer.append(chunk)
            }
            
            let result = streamResult.map { buffer.data as Data? }
            cache = result
            return result
        }
    }
}

private final class ThreadSafeBuffer: @unchecked Sendable {
    private var _data = Data()
    private let lock = NSLock()

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return _data
    }

    func append(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        _data.append(chunk)
    }
}
