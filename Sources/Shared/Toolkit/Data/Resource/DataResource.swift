//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Creates a `Resource` serving raw data.
public actor DataResource: Resource {
    public let sourceURL: AbsoluteURL?

    private let makeData: () async -> ReadResult<Data>

    /// Creates a `Resource` serving an array of bytes.
    public init(
        data: @autoclosure @escaping () -> Data,
        sourceURL: AbsoluteURL? = nil
    ) {
        self.init(sourceURL: sourceURL) {
            .success(data())
        }
    }

    /// Creates a `Resource` serving a string encoded as UTF-8.
    public init(string: String, sourceURL: AbsoluteURL? = nil) {
        self.init(sourceURL: sourceURL) {
            // It's safe to force-unwrap when using a unicode encoding.
            // https://www.objc.io/blog/2018/02/13/string-to-data-and-back/
            .success(string.data(using: .utf8)!)
        }
    }

    /// Creates a `Resource` serving an array of bytes.
    public init(
        sourceURL: AbsoluteURL? = nil,
        makeData: @escaping () async -> ReadResult<Data>
    ) {
        self.makeData = makeData
        self.sourceURL = sourceURL
    }

    public func estimatedLength() async -> ReadResult<UInt64?> {
        .success(nil)
    }

    public func properties() async -> ReadResult<ResourceProperties> {
        .success(ResourceProperties())
    }

    private var _data: ReadResult<Data>?

    private func data() async -> ReadResult<Data> {
        if _data == nil {
            _data = await makeData()
        }
        return _data!
    }

    public func stream(
        range: Range<UInt64>?,
        consume: @escaping (Data) -> Void
    ) async -> ReadResult<Void> {
        await data().map { data in
            let length = UInt64(data.count)
            if let range = range?.clamped(to: 0 ..< length) {
                consume(data[range])
            } else {
                consume(data)
            }

            return ()
        }
    }
}
