//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public actor FormatSnifferBlob {
    private let source: Streamable
    private let xmlDocumentFactory: XMLDocumentFactory

    // Caches
    private var length: ReadResult<UInt64?>?
    private var bytes: ReadResult<Data?>?
    private var string: ReadResult<String?>?
    private var json: ReadResult<Any?>?
    private var xml: ReadResult<XMLDocument?>?

    public init(source: Streamable) {
        self.source = source
        xmlDocumentFactory = DefaultXMLDocumentFactory()
    }

    /// Reads the bytes at the given range.
    ///
    /// Out-of-range indexes are clamped to the available length automatically.
    func read(range: Range<UInt64>) async -> ReadResult<Data> {
        await source.read(range: range)
    }

    /// Reads the whole bytes.
    ///
    /// If the resource is too large to be read in memory, will return nil.
    func read() async -> ReadResult<Data?> {
        if bytes == nil {
            bytes = await length()
                .asyncFlatMap { length in
                    guard let length = length, length < 5 * 1000 * 1000 else {
                        return .success(nil)
                    }

                    return await source.read()
                        .map { $0 as Data? }
                }
        }
        return bytes!
    }

    /// Reads the whole content as a UTF-8 `String`.
    func readAsString() async -> ReadResult<String?> {
        if string == nil {
            string = await read().map {
                $0.flatMap { String(data: $0, encoding: .utf8) }
            }
        }
        return string!
    }

    /// Reads the whole content as JSON.
    func readAsJSON() async -> ReadResult<Any?> {
        if json == nil {
            json = await read().map {
                $0.flatMap {
                    try? JSONSerialization.jsonObject(with: $0)
                }
            }
        }
        return json!
    }

    /// Reads the whole content as an XML document.
    func readAsXML() async -> ReadResult<XMLDocument?> {
        if xml == nil {
            xml = await read().asyncMap {
                await $0.asyncFlatMap {
                    try? await xmlDocumentFactory.open(data: $0, namespaces: [])
                }
            }
        }
        return xml!
    }

    private func length() async -> ReadResult<UInt64?> {
        if length == nil {
            length = await source.estimatedLength()
        }
        return length!
    }
}
