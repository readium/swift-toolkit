//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public actor FormatSnifferBlob {
    private let source: Streamable
    private let xmlDocumentFactory: XMLDocumentFactory

    // Caches
    private var _length: Result<UInt64?, ReadError>?
    private var _bytes: Result<Data?, ReadError>?
    private var _string: Result<String?, ReadError>?
    private var _json: Result<JSONValue?, ReadError>?
    private var _xml: Result<XMLDocument?, ReadError>?

    public init(source: Streamable) {
        self.source = source
        xmlDocumentFactory = DefaultXMLDocumentFactory()
    }

    /// Reads the bytes at the given range.
    ///
    /// Out-of-range indexes are clamped to the available length automatically.
    func read(range: Range<UInt64>) async throws(ReadError) -> Data {
        try await source.read(range: range)
    }

    /// Reads the whole bytes.
    ///
    /// If the resource is too large to be read in memory, will return nil.
    func read() async throws(ReadError) -> Data? {
        if _bytes == nil {
            do {
                let length = try await length()
                guard let length = length, length < 5 * 1000 * 1000 else {
                    _bytes = .success(nil)
                    return nil
                }
                let data = try await source.read()
                _bytes = .success(data)
            } catch {
                _bytes = .failure(error)
            }
        }
        switch _bytes! {
        case let .success(data): return data
        case let .failure(error): throw error
        }
    }

    /// Reads the whole content as a UTF-8 `String`.
    func readAsString() async throws(ReadError) -> String? {
        if _string == nil {
            do {
                let data = try await read()
                _string = .success(data.flatMap { String(data: $0, encoding: .utf8) })
            } catch {
                _string = .failure(error)
            }
        }
        switch _string! {
        case let .success(string): return string
        case let .failure(error): throw error
        }
    }

    /// Reads the whole content as JSON.
    func readAsJSON() async throws(ReadError) -> JSONValue? {
        if _json == nil {
            do {
                let data = try await read()
                _json = .success(data.flatMap { try? JSONValue(jsonData: $0) })
            } catch {
                _json = .failure(error)
            }
        }
        switch _json! {
        case let .success(json): return json
        case let .failure(error): throw error
        }
    }

    /// Reads the whole content as an XML document.
    func readAsXML() async throws(ReadError) -> XMLDocument? {
        if _xml == nil {
            do {
                let data = try await read()
                let xml: XMLDocument? = {
                    guard let data = data else { return nil }
                    return try? xmlDocumentFactory.open(data: data, namespaces: [])
                }()
                _xml = .success(xml)
            } catch {
                _xml = .failure(error)
            }
        }
        switch _xml! {
        case let .success(xml): return xml
        case let .failure(error): throw error
        }
    }

    private func length() async throws(ReadError) -> UInt64? {
        if _length == nil {
            do {
                _length = try await .success(source.estimatedLength())
            } catch {
                _length = .failure(error)
            }
        }
        switch _length! {
        case let .success(length): return length
        case let .failure(error): throw error
        }
    }
}
