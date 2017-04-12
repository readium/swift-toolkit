//
//  FetcherEpub.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 4/12/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

internal protocol ContentFilters {

    init()

    func apply(to data: Data, at path: String) throws -> Data

    func apply(to inputStream: SeekableInputStream, at path: String) throws -> SeekableInputStream
}
// Default implementation
internal extension ContentFilters {

    internal func apply(to data: Data, at path: String) throws -> Data {
        return data
    }

    internal func apply(to inputStream: SeekableInputStream, at path: String) throws -> SeekableInputStream {
        return inputStream
    }
}

internal class ContentFiltersEpub: ContentFilters {
    required init() {}
    
}

internal class ContentFiltersCbz: ContentFilters {
    required init() {}
}
