//
//  FailureResource.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 09/08/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Creates a Resource that will always return the given `error`.
public final class FailureResource: Resource {
    
    private let error: ResourceError
    
    public init(link: Link, error: ResourceError) {
        self.link = link
        self.error = error
    }
    
    public let link: Link
    
    public var length: ResourceResult<UInt64> { .failure(error) }
    
    public func read(range: Range<UInt64>?) -> ResourceResult<Data> {
        return .failure(error)
    }
    
    public func close() {}
    
}
