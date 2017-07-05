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


    func apply(to input: Data, of publication: Publication, at path: String) throws -> Data
}
// Default implementation. Do nothing.
internal extension ContentFilters {

    internal func apply(to input: SeekableInputStream,
                        of publication: Publication, at path: String) throws -> SeekableInputStream {
        // Do nothing.
        return input
    }

    internal func apply(to input: Data,
                        of publication: Publication, at path: String) throws -> Data {
        // Do nothing.
        return input
    }
}

/// Content filter specialization for EPUB/OEBPS.
/// Filters:
///     - Font deobfuscation using the Decoder object.
///     - HTML injections (scripts css/js).
internal class ContentFiltersEpub: ContentFilters {

    /// The Decoder object is used for font deobfusction of resources.
    var decoder: Decoder!

    required init() {
        decoder = Decoder()
    }

    /// Apply the Epub content filters on the content of the `input` stream para-
    /// meter.
    ///
    /// - Parameters:
    ///   - input: The InputStream containing the data to process.
    ///   - publication: The publiaction containing the resource.
    ///   - path: The path of the resource relative to the Publication.
    /// - Returns: The resource after the filters have been applyed.
    internal func apply(to input: SeekableInputStream,
                        of publication: Publication, at path: String) -> SeekableInputStream
    {
        var decodedInputStream = decoder.decoding(input, of: publication, at: path)

        // Inject additional content in the resource if test succeed.
        // if type == "application/xhtml+xml"
        //   if (publication layout is 'reflow' &&  resource is `not specified`)
        //     || resource is 'reflow'
        //       - inject pagination
        if let link = publication.link(withHref: path),
            link.typeLink == "application/xhtml+xml" || link.typeLink == "text/html",
            publication.metadata.rendition.layout == .reflowable && link.properties.layout == nil
                || link.properties.layout == "reflowable"
        {
            decodedInputStream = injectHtml(in: decodedInputStream)
        }

        return decodedInputStream
    }

    /// Apply the epub content filters on the content of the `input` Data.
    ///
    /// - Parameters:
    ///   - input: The Data containing the data to process.
    ///   - publication: The publication containing the resource.
    ///   - path: The path of the resource relative to the Publication.
    /// - Returns: The resource after the filters have been applyed.
    internal func apply(to input: Data,
                        of publication: Publication, at path: String)  -> Data
    {
        let inputStream = DataInputStream(data: input)
        var decodedInputStream = decoder.decoding(inputStream, of: publication, at: path)

        guard let dataInputstream = decodedInputStream as? DataInputStream else {
            return input
        }
        // Inject additional content in the resource if test succeed.
        if let link = publication.link(withHref: path),
            link.typeLink == "application/xhtml+xml" || link.typeLink == "text/html",
            publication.metadata.rendition.layout == .reflowable && link.properties.layout == nil
                || link.properties.layout == "reflowable"
        {
            decodedInputStream = injectHtml(in: decodedInputStream)
        }

        return dataInputstream.data
    }

    fileprivate func injectHtml(in stream: SeekableInputStream) -> SeekableInputStream {

        let bufferSize = Int(stream.length)
        var buffer = Array<UInt8>(repeating: 0, count: bufferSize)

        stream.open()
        let numberOfBytesRead = (stream as InputStream).read(&buffer, maxLength: bufferSize)
        let data = Data(bytes: buffer, count: numberOfBytesRead)

        guard var resourceHtml = String.init(data: data, encoding: String.Encoding.utf8) else {
            return stream
        }
        let headIndex = resourceHtml.endIndex(of: "<head>")

        let viewport = "\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\"/>\n"
        let style = "<link rel=\"stylesheet\" type=\"text/css\" href=\"http://localhost:8080/Reflow.css\"/>"

        resourceHtml = resourceHtml.insert(string: style, at: headIndex!)
        resourceHtml = resourceHtml.insert(string: viewport, at: headIndex!)

        let enhancedData = resourceHtml.data(using: String.Encoding.utf8)
        let enhancedStream = DataInputStream(data: enhancedData!)
        
        return enhancedStream
    }

}

/// Content filter specialization for CBZ.
internal class ContentFiltersCbz: ContentFilters {
    var decoder: Decoder!

    required init() {
        decoder = Decoder()
    }
}
