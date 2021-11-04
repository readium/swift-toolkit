//
//  DataResource.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 09/08/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Creates a `Resource` serving raw data.
public final class DataResource: Resource {
    
    private let makeData: () throws -> Data
    private lazy var data = ResourceResult<Data> { try makeData() }

    /// Creates a `Resource` serving an array of bytes.
    public init(link: Link, data: @autoclosure @escaping () throws -> Data = Data()) {
        self.link = link
        self.makeData = data
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
        return data.map { data in
            let length = UInt64(data.count)
            if let range = range?.clamped(to: 0..<length) {
                return data[range]
            } else {
                return data
            }
        }
    }
    
    public func close() {}
    
}
