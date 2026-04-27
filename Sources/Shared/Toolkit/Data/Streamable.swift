//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Acts as a proxy to an actual data source by handling read access.
public protocol Streamable: Closeable {
    /// Returns data length from metadata if available.
    ///
    /// This value must be treated as a hint, as it might not reflect the
    /// actual bytes length. To get the real length, you need to read the whole
    /// resource.
    func estimatedLength() async -> ReadResult<UInt64?>

    /// Reads the bytes at the given range in a streaming fashion.
    ///
    /// - Parameters:
    ///   - range: When null, the whole content is returned. Out-of-range
    ///     indexes are clamped to the available length automatically.
    ///   - consume: Callback called for each chunk of data received. Callers
    ///     are responsible to accumulate the data if needed.
    func stream(
        range: Range<UInt64>?,
        consume: @escaping (Data) -> Void
    ) async -> ReadResult<Void>
}

public extension Streamable {
    /// Reads the whole bytes at the given range in a streaming fashion.
    ///
    /// - Parameters:
    ///   - consume: Callback called for each chunk of data received. Callers
    ///     are responsible to accumulate the data if needed.
    // FIXME: Task cancellation
    func stream(consume: @escaping (Data) -> Void) async -> ReadResult<Void> {
        await stream(range: nil, consume: consume)
    }

    /// Reads the whole bytes.
    func read() async -> ReadResult<Data> {
        await read(range: nil)
    }

    /// Reads the bytes at the given range.
    ///
    /// When `range` is null, the whole content is returned. Out-of-range
    /// indexes are clamped to the available length automatically.
    func read(range: Range<UInt64>?) async -> ReadResult<Data> {
        var data = Data()
        let result = await stream(range: range) {
            data += $0
        }
        return result.map { data }
    }

    /// Reads the whole content as a `String`.
    @available(*, deprecated, message: "Use `read().asString()` instead")
    func readAsString(encoding: String.Encoding = .utf8) async -> ReadResult<String> {
        await read().flatMap {
            guard let string = String(data: $0, encoding: encoding) else {
                return .failure(.decoding("Not a valid \(encoding) string"))
            }
            return .success(string)
        }
    }

    /// Reads the whole content as a JSON value.
    @available(*, deprecated, message: "Use `read().asJSON()` instead")
    func readAsJSON<T: Any>(options: JSONSerialization.ReadingOptions = []) async -> ReadResult<T> {
        await read().flatMap {
            do {
                guard let json = try JSONSerialization.jsonObject(with: $0) as? T else {
                    return .failure(.decoding(JSONError.parsing(T.self)))
                }
                return .success(json)
            } catch {
                return .failure(.decoding(error))
            }
        }
    }

    /// Reads the whole content as a JSON object.
    @available(*, deprecated, message: "Use `read().asJSONObject()` instead")
    func readAsJSONObject(options: JSONSerialization.ReadingOptions = []) async -> ReadResult<[String: Any]> {
        await readAsJSON()
    }
}

// MARK: - Read Monitoring Memory

package enum ReadMonitoringMemoryError: Error {
    /// Read error thrown by the underlying stream.
    case read(ReadError)

    /// Thrown when there is not enough memory to safely load a resource.
    /// - Parameters:
    ///     `estimatedLength`: Estimated byte length of the resource, if known.
    ///     `availableMemory`: Available memory at the time of the failure.
    case outOfMemory(estimatedLength: UInt64?, availableMemory: UInt64)

    /// Task cancelled.
    case cancelled
}

package extension Streamable {
    /// Reads the whole bytes while monitoring available memory to avoid OOM
    /// crashes.
    ///
    /// - Parameter memoryFactor: Minimum ratio of available memory to data size
    ///   required at all times. A factor of 2 means at least 2x the data size
    ///   must remain available, to account for the memory needed to process the
    ///   data on top of storing it.
    /// - Throws: `OutOfMemoryError` if memory is insufficient,
    ///  `CancellationError` if cancelled, or `ReadError` if the underlying
    ///   stream fails.
    func readMonitoringMemory(factor: UInt64 = 2) async throws(ReadMonitoringMemoryError) -> Data {
        let estimated = await estimatedLength().getOrNil() ?? nil

        // `availableMemory` will be 0 on the Simulator.
        let availableMemory = UInt64(os_proc_available_memory())
        if availableMemory > 0, let length = estimated, length > availableMemory / factor {
            throw .outOfMemory(estimatedLength: length, availableMemory: availableMemory)
        }

        var data = Data()
        if let capacity = estimated {
            data.reserveCapacity(Int(capacity))
        }

        var error: ReadMonitoringMemoryError? = nil {
            didSet {
                data = Data()
            }
        }

        let streamResult = await stream { chunk in
            guard error == nil else {
                return
            }

            guard !Task.isCancelled else {
                error = .cancelled
                return
            }

            let availableMemory = UInt64(os_proc_available_memory())
            guard availableMemory == 0 || UInt64(chunk.count) < availableMemory else {
                error = .outOfMemory(estimatedLength: estimated, availableMemory: availableMemory)
                return
            }

            data.append(chunk)
        }

        if let error {
            throw error
        }

        switch streamResult {
        case .success:
            return data
        case let .failure(error):
            throw .read(error)
        }
    }
}
