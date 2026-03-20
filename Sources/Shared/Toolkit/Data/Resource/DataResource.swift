//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Creates a `Resource` serving raw data.
public actor DataResource: Resource {
    public let sourceURL: AbsoluteURL?

    private let makeData: () async throws(ReadError) -> Data

    /// Creates a `Resource` serving an array of bytes.
    public init(
        data: @autoclosure @escaping () -> Data,
        sourceURL: AbsoluteURL? = nil
    ) {
        self.init(sourceURL: sourceURL) {
            data()
        }
    }

    /// Creates a `Resource` serving a string encoded as UTF-8.
    public init(string: String, sourceURL: AbsoluteURL? = nil) {
        self.init(sourceURL: sourceURL) {
            // It's safe to force-unwrap when using a unicode encoding.
            // https://www.objc.io/blog/2018/02/13/string-to-data-and-back/
            string.data(using: .utf8)!
        }
    }

    /// Creates a `Resource` serving an array of bytes.
    public init(
        sourceURL: AbsoluteURL? = nil,
        makeData: @escaping () async throws(ReadError) -> Data
    ) {
        self.makeData = makeData
        self.sourceURL = sourceURL
    }

    public func estimatedLength() async throws(ReadError) -> UInt64? {
        nil
    }

    public func properties() async throws(ReadError) -> ResourceProperties {
        ResourceProperties()
    }

    private var _data: Result<Data, ReadError>?

    private func data() async throws(ReadError) -> Data {
        if _data == nil {
            do {
                _data = try await .success(makeData())
            } catch {
                _data = .failure(error)
            }
        }
        switch _data! {
        case let .success(data): return data
        case let .failure(error): throw error
        }
    }

    public func stream(
        range: Range<UInt64>?,
        consume: @escaping (Data) -> Void
    ) async throws(ReadError) {
        let data = try await data()
        let length = UInt64(data.count)
        if let range = range?.clamped(to: 0 ..< length) {
            consume(data[range])
        } else {
            consume(data)
        }
    }
}
