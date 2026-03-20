//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension Data {
    /// Decodes the data as a `T` using the given `decoder`.
    ///
    /// - Returns: The decoded `T`, or a `ReadError.decoding` error.
    func decode<T>(_ decoder: (Data) throws -> T) throws(ReadError) -> T {
        do {
            return try decoder(self)
        } catch let error as ReadError {
            throw error
        } catch {
            throw .decoding(error)
        }
    }

    /// Decodes the data as a `String`.
    func asString(encoding: String.Encoding = .utf8) throws(ReadError) -> String {
        guard let string = String(data: self, encoding: encoding) else {
            throw .decoding("Not a valid \(encoding) string")
        }
        return string
    }

    /// Decodes the data as a JSON value.
    func asJSON<T: Any>(options: JSONSerialization.ReadingOptions = []) throws(ReadError) -> T {
        try decode { data in
            guard let json = try JSONSerialization.jsonObject(with: data, options: options) as? T else {
                throw JSONError.parsing(T.self)
            }
            return json
        }
    }

    /// Decodes the data as a JSON object.
    func asJSONObject(options: JSONSerialization.ReadingOptions = []) throws(ReadError) -> [String: Any] {
        try asJSON(options: options)
    }

    /// Decodes the data as an XML document.
    func asXML(using factory: XMLDocumentFactory, namespaces: [XMLNamespace] = []) throws(ReadError) -> XMLDocument {
        try decode { try $0.asXMLInternal(using: factory, namespaces: namespaces) }
    }

    /// Decodes the data as a `JSONValue`.
    func asJSONValue(options: JSONSerialization.ReadingOptions = []) throws(ReadError) -> JSONValue {
        try decode { data in
            let json = try JSONSerialization.jsonObject(with: data, options: options)
            guard let value = JSONValue(json) else {
                throw JSONError.parsing(JSONValue.self)
            }
            return value
        }
    }

    /// Decodes the data as a JSON object.
    func asJSONObjectValue(options: JSONSerialization.ReadingOptions = []) throws(ReadError) -> [String: JSONValue] {
        let value = try asJSONValue(options: options)
        guard let dict = value.object else {
            throw ReadError.decoding(JSONError.parsing([String: JSONValue].self))
        }
        return dict
    }
}

public extension Optional where Wrapped == Data {
    /// Decodes the data as a `T` using the given `decoder`.
    ///
    /// - Returns: `nil` if the data is absent, the decoded `T` if data is
    ///   present, or a `ReadError.decoding` error if decoding fails.
    func decode<T>(_ decoder: (Data) throws -> T) throws(ReadError) -> T? {
        guard let self else {
            return nil
        }
        return try self.decode(decoder)
    }

    /// Decodes the data as a `String`.
    func asString(encoding: String.Encoding = .utf8) throws(ReadError) -> String? {
        guard let self else { return nil }
        return try self.asString(encoding: encoding)
    }

    /// Decodes the data as a JSON value.
    func asJSON<T: Any>(options: JSONSerialization.ReadingOptions = []) throws(ReadError) -> T? {
        guard let self else { return nil }
        return try self.asJSON(options: options) as T
    }

    /// Decodes the data as a JSON object.
    func asJSONObject(options: JSONSerialization.ReadingOptions = []) throws(ReadError) -> [String: Any]? {
        try asJSON(options: options)
    }

    /// Decodes the data as an XML document.
    func asXML(using factory: XMLDocumentFactory, namespaces: [XMLNamespace] = []) throws(ReadError) -> XMLDocument? {
        guard let self else { return nil }
        return try self.asXML(using: factory, namespaces: namespaces)
    }

    /// Decodes the data as a `JSONValue`.
    func asJSONValue(options: JSONSerialization.ReadingOptions = []) throws(ReadError) -> JSONValue? {
        guard let self else { return nil }
        return try self.asJSONValue(options: options)
    }

    /// Decodes the data as a JSON object.
    func asJSONObjectValue(options: JSONSerialization.ReadingOptions = []) throws(ReadError) -> [String: JSONValue]? {
        guard let self else { return nil }
        return try self.asJSONObjectValue(options: options)
    }
}

private extension Data {
    func asXMLInternal(using factory: XMLDocumentFactory, namespaces: [XMLNamespace] = []) throws -> XMLDocument {
        try factory.open(data: self, namespaces: namespaces)
    }
}
