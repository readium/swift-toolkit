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

package extension Streamable {
    /// Reads the whole bytes while monitoring available memory to avoid OOM
    /// crashes.
    func readMonitoringMemory() async throws(ReadError) -> Data {
        let estimated = await estimatedLength().getOrNil() ?? nil

        guard !Task.isCancelled else {
            throw .cancelled
        }

        // `availableMemory` will be 0 on the Simulator.
        let availableMemory = os_proc_available_memory()
        if availableMemory > 0, let length = estimated, length > availableMemory {
            throw .outOfMemory(nil)
        }

        var data = Data()
        if let estimated, estimated <= UInt64(Int.max) {
            data.reserveCapacity(Int(estimated))
        }

        var error: ReadError? = nil {
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

            let availableMemory = os_proc_available_memory()
            guard availableMemory == 0 || data.count + chunk.count <= availableMemory else {
                error = .outOfMemory(nil)
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
            throw error
        }
    }
}
