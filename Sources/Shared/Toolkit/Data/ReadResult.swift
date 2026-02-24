//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public typealias ReadResult<Success> = Result<Success, ReadError>

public extension ReadResult<Data> {
    /// Decodes the data as a `T` using the given `decoder`.
    ///
    /// - Returns: The decoded `T`, or a `ReadError.decoding` error.
    func decode<T>(_ decoder: (Data) throws -> T) -> ReadResult<T> {
        flatMap { data in
            do {
                return try .success(decoder(data))
            } catch {
                return .failure(.decoding(error))
            }
        }
    }

    /// Decodes the data as a `String`.
    func asString(encoding: String.Encoding = .utf8) async -> ReadResult<String> {
        decode { data in
            guard let string = String(data: data, encoding: encoding) else {
                throw DebugError("Not a valid \(encoding) string")
            }
            return string
        }
    }

    /// Decodes the data as a JSON value.
    func asJSON<T: Any>(options: JSONSerialization.ReadingOptions = []) -> ReadResult<T> {
        decode { data in
            guard let json = try JSONSerialization.jsonObject(with: data) as? T else {
                throw JSONError.parsing(T.self)
            }
            return json
        }
    }

    /// Decodes the data as a JSON object.
    func asJSONObject(options: JSONSerialization.ReadingOptions = []) -> ReadResult<[String: Any]> {
        asJSON()
    }

    /// Decodes the data as an XML document.
    func asXML(using factory: XMLDocumentFactory, namespaces: [XMLNamespace] = []) async -> ReadResult<XMLDocument> {
        decode { data in
            try factory.open(data: data, namespaces: [])
        }
    }
}

public extension ReadResult<Data?> {
    /// Decodes the data as a `T` using the given `decoder`.
    ///
    /// - Returns: The decoded `T`, or a `ReadError.decoding` error.
    func decode<T>(_ decoder: (Data) throws -> T) -> ReadResult<T?> {
        flatMap { data in
            guard let data = data else {
                return .success(nil)
            }
            do {
                return try .success(decoder(data))
            } catch {
                return .failure(.decoding(error))
            }
        }
    }

    /// Decodes the data as a JSON value.
    func asJSON<T: Any>(options: JSONSerialization.ReadingOptions = []) -> ReadResult<T?> {
        decode { data in
            guard let json = try JSONSerialization.jsonObject(with: data) as? T else {
                throw JSONError.parsing(T.self)
            }
            return json
        }
    }

    /// Decodes the data as a JSON object.
    func asJSONObject(options: JSONSerialization.ReadingOptions = []) -> ReadResult<[String: Any]?> {
        asJSON()
    }

    /// Decodes the data as an XML document.
    func asXML(using factory: XMLDocumentFactory, namespaces: [XMLNamespace] = []) async -> ReadResult<XMLDocument?> {
        decode { data in
            try factory.open(data: data, namespaces: [])
        }
    }
}
