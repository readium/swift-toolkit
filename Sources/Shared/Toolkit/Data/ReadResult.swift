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
    func asString(encoding: String.Encoding = .utf8) -> ReadResult<String> {
        decode { try $0.asString(encoding: encoding) }
    }

    /// Decodes the data as a JSON value.
    func asJSON<T: Any>(options: JSONSerialization.ReadingOptions = []) -> ReadResult<T> {
        decode { try $0.asJSON(options: options) }
    }

    /// Decodes the data as a JSON object.
    func asJSONObject(options: JSONSerialization.ReadingOptions = []) -> ReadResult<[String: Any]> {
        asJSON(options: options)
    }

    /// Decodes the data as an XML document.
    func asXML(using factory: XMLDocumentFactory, namespaces: [XMLNamespace] = []) -> ReadResult<XMLDocument> {
        decode { try $0.asXML(using: factory, namespaces: namespaces) }
    }
}

public extension ReadResult<Data?> {
    /// Decodes the data as a `T` using the given `decoder`.
    ///
    /// - Returns: `nil` if the data is absent, the decoded `T` if data is
    ///   present, or a `ReadError.decoding` error if decoding fails.
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

    /// Decodes the data as a `String`.
    func asString(encoding: String.Encoding = .utf8) -> ReadResult<String?> {
        decode { try $0.asString(encoding: encoding) }
    }

    /// Decodes the data as a JSON value.
    func asJSON<T: Any>(options: JSONSerialization.ReadingOptions = []) -> ReadResult<T?> {
        decode { try $0.asJSON(options: options) }
    }

    /// Decodes the data as a JSON object.
    func asJSONObject(options: JSONSerialization.ReadingOptions = []) -> ReadResult<[String: Any]?> {
        asJSON(options: options)
    }

    /// Decodes the data as an XML document.
    func asXML(using factory: XMLDocumentFactory, namespaces: [XMLNamespace] = []) -> ReadResult<XMLDocument?> {
        decode { try $0.asXML(using: factory, namespaces: namespaces) }
    }
}

private extension Data {
    /// Decodes the data as a `String`.
    func asString(encoding: String.Encoding = .utf8) throws -> String {
        guard let string = String(data: self, encoding: encoding) else {
            throw DebugError("Not a valid \(encoding) string")
        }
        return string
    }

    /// Decodes the data as a JSON value.
    func asJSON<T: Any>(options: JSONSerialization.ReadingOptions = []) throws -> T {
        guard let json = try JSONSerialization.jsonObject(with: self, options: options) as? T else {
            throw JSONError.parsing(T.self)
        }
        return json
    }

    /// Decodes the data as a JSON object.
    func asJSONObject(options: JSONSerialization.ReadingOptions = []) throws -> [String: Any] {
        try asJSON(options: options)
    }

    /// Decodes the data as an XML document.
    func asXML(using factory: XMLDocumentFactory, namespaces: [XMLNamespace] = []) throws -> XMLDocument {
        try factory.open(data: self, namespaces: namespaces)
    }
}
