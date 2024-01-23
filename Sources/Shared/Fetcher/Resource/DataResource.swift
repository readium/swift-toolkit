//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Creates a `Resource` serving raw data.
public final class DataResource: Resource {
    private let makeData: () throws -> Data
    private lazy var data = ResourceResult<Data> { try makeData() }

    /// Creates a `Resource` serving an array of bytes.
    public init(link: Link, data: @autoclosure @escaping () throws -> Data = Data()) {
        self.link = link
        makeData = data
    }

    /// Creates a `Resource` serving a string encoded as UTF-8.
    public convenience init(link: Link, string: String) {
        // It's safe to force-unwrap when using a unicode encoding.
        // https://www.objc.io/blog/2018/02/13/string-to-data-and-back/
        self.init(link: link, data: string.data(using: .utf8)!)
    }

    public let link: Link

    public let file: URL? = nil

    public var length: ResourceResult<UInt64> { data.map { UInt64($0.count) } }

    public func read(range: Range<UInt64>?) -> ResourceResult<Data> {
        data.map { data in
            let length = UInt64(data.count)
            if let range = range?.clamped(to: 0 ..< length) {
                return data[range]
            } else {
                return data
            }
        }
    }

    public func close() {}
}
