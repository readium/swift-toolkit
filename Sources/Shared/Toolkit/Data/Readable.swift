//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Acts as a proxy to an actual data source by handling read access.
public protocol Readable: AsyncCloseable {

    /// Returns data length from metadata if available, or calculated from reading the bytes otherwise.
    ///
    /// This value must be treated as a hint, as it might not reflect the actual bytes length. To get
    /// the real length, you need to read the whole resource.
    func length() async -> ReadResult<UInt64>
   
    /// Reads the bytes at the given range.
    ///
    /// When `range` is null, the whole content is returned. Out-of-range indexes are clamped to the
    /// available length automatically.
    func read(range: Range<UInt64>?) async -> ReadResult<Data>
}

public extension Readable {

    /// Reads the whole bytes.
    func read() async -> ReadResult<Data> {
        await read(range: nil)
    }
    
    /// Reads the whole content as a `String`.
    func readAsString(encoding: String.Encoding = .utf8) async -> ReadResult<String> {
        await read().flatMap {
            guard let string = String(data: $0, encoding: encoding) else {
                return .failure(.decoding(DebugError("Not a valid \(encoding) string")))
            }
            return .success(string)
        }
    }
    
    /// Reads the whole content as a JSON object.
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
}

public typealias ReadResult<Success> = Result<Success, ReadError>

/// Errors occurring while reading a resource.
public enum ReadError: Error {
    /// An error occurred while trying to access the content.
    ///
    /// At the moment, `AccessError`s constructed by the toolkit can be either a `FileSystemError`
    /// or an `HttpError`.
    case access(AccessError)
    
    /// Content doesn't match what was expected and cannot be interpreted.
    ///
    /// For instance, this error can be reported if a ZIP archive looks invalid,
    /// a publication doesn't conform to its format, or a JSON resource cannot be decoded.
    case decoding(Error)
    
    /// An operation could not be performed at some point.
    ///
    /// For instance, this error can occur no matter the level of indirection when trying
    /// to read ranges or getting length if any component the data has to pass through
    /// doesn't support that.
    case unsupportedOperation(Error)
}

/// Marker interface for source-specific access errors.
public protocol AccessError: Error {}
