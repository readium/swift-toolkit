//
//  FetcherEpub.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 4/12/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// Protocol defining the content filters. They are implemented below and used
/// in the fetcher. They come in different flavors depending of the container
/// data mimetype.
internal protocol ContentFilters {
    var decoder: Decoder! { get set }

    init()

    func apply(to input: SeekableInputStream, of publication: Publication, at path: String) throws -> SeekableInputStream
}
// Default implementation. Do nothing.
internal extension ContentFilters {

    internal func apply(to input: SeekableInputStream,
                        of publication: Publication, at path: String) throws -> SeekableInputStream {
        // Do nothing.
        return input
    }
}

/// Content filter specialization for EPUB.
internal class ContentFiltersEpub: ContentFilters {
    var decoder: Decoder!

    required init() {
        decoder = Decoder()
    }

    internal func apply(to input: SeekableInputStream,
                        of publication: Publication, at path: String) throws -> SeekableInputStream {
        let inputStream = decoder.decode(input, of: publication, at: path)
        // var data
        // other transformations...
        return inputStream
    }
}

/// Content filter specialization for CBZ.
internal class ContentFiltersCbz: ContentFilters {
    var decoder: Decoder!

    required init() {
        decoder = Decoder()
    }
}
