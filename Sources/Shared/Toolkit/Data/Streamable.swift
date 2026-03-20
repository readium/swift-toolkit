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
    func estimatedLength() async throws(ReadError) -> UInt64?

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
    ) async throws(ReadError)
}

public extension Streamable {
    /// Reads the whole bytes at the given range in a streaming fashion.
    ///
    /// - Parameters:
    ///   - consume: Callback called for each chunk of data received. Callers
    ///     are responsible to accumulate the data if needed.
    func stream(consume: @escaping (Data) -> Void) async throws(ReadError) {
        try await stream(range: nil, consume: consume)
    }

    /// Reads the whole bytes.
    func read() async throws(ReadError) -> Data {
        try await read(range: nil)
    }

    /// Reads the bytes at the given range.
    ///
    /// When `range` is null, the whole content is returned. Out-of-range
    /// indexes are clamped to the available length automatically.
    func read(range: Range<UInt64>?) async throws(ReadError) -> Data {
        var data = Data()
        try await stream(range: range) {
            data += $0
        }
        return data
    }

    /// Reads the whole content as a `String`.
    @available(*, deprecated, message: "Use `read().asString()` instead")
    func readAsString(encoding: String.Encoding = .utf8) async throws(ReadError) -> String {
        let data = try await read()
        guard let string = String(data: data, encoding: encoding) else {
            throw .decoding("Not a valid \(encoding) string")
        }
        return string
    }

    /// Reads the whole content as a JSON value.
    @available(*, deprecated, message: "Use `read().asJSON()` instead")
    func readAsJSON<T: Any>(options: JSONSerialization.ReadingOptions = []) async throws(ReadError) -> T {
        let data = try await read()
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? T else {
                throw ReadError.decoding(JSONError.parsing(T.self))
            }
            return json
        } catch let error as ReadError {
            throw error
        } catch {
            throw ReadError.decoding(error)
        }
    }

    /// Reads the whole content as a JSON object.
    @available(*, deprecated, message: "Use `read().asJSONObject()` instead")
    func readAsJSONObject(options: JSONSerialization.ReadingOptions = []) async throws(ReadError) -> [String: Any] {
        try await readAsJSON()
    }
}
