//
//  RDGCDServerResourceResponse.swift
//  r2-streamer-swift
//
//  Created by Olivier Körner on 13/01/2017.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared
import GCDWebServer

extension GCDWebServerResponse: Loggable {}

/// Errors thrown by the `WebServerResourceResponse`
///
/// - streamOpenFailed: The stream is not open, stream.open() failed.
/// - invalidRange: The range queried is invalid.
public enum WebServerResponseError: Error {
    case streamOpenFailed
    case invalidRange
}

/// The object containing the response's ressource data.
/// If the ressource to be served is too big, multiple responses will be created.
open class WebServerResourceResponse: GCDWebServerFileResponse {

    // The range of data served on this response (?)
    var range: Range<UInt64>?
    var inputStream: SeekableInputStream
    lazy var totalNumberOfBytesRead = UInt64(0)
    let bufferSize = 32 * 1024
    var buffer: Array<UInt8>

    /// Initialise the WebServerRessourceResponse object, defining what will be
    /// served.
    ///
    /// - Parameters:
    ///   - inputStream: The data stream containing the ressource's data to
    ///                  serve in the response.
    ///   - range: The range of ressource's data served previously, if any.
    ///   - contentType: The content-type of the response's ressource.
    public init(inputStream: SeekableInputStream, range: NSRange?, contentType: String) {
        let streamLength = inputStream.length

        // Initialize buffer
        buffer = Array<UInt8>(repeating: 0, count: bufferSize)
        // Set inputStream
        self.inputStream = inputStream
        // If range is non nil - means it's not the first part (?)
        if let range = range {
            WebServerResourceResponse.log(.debug, "Request range at \(range.location) remaining: \(range.length).")
            /// Return a range of what to read next (nothing, next part, whole data).
            func getNextRange(after range: NSRange,
                              forStreamOfLength streamLength: UInt64) -> Range<UInt64> {
                let newRange: Range<UInt64>

                if range.location == Int.max {
                    let len = min(UInt64(range.length), streamLength)

                    newRange = (streamLength - len)..<streamLength
                } else if range.location < 0 {
                    // TODO: negative range location
                    // The whole data for now
                    newRange = 0..<streamLength
                } else {
                    let currentPosition = min(UInt64(range.location), streamLength)
                    let remainingLength = streamLength - currentPosition
                    let length: UInt64

                    if range.length == -1 {
                        length = remainingLength
                    } else {
                        length = min(UInt64(range.length), remainingLength)
                    }
                    newRange = currentPosition..<(currentPosition + length)
                }
                return newRange
            }
            self.range = getNextRange(after: range,
                                      forStreamOfLength: streamLength)
        } else /* nil */ {
            self.range = 0..<streamLength
        }
        super.init()
        // Response
        if let range = self.range {
            let lower = range.lowerBound
            let upper = (range.upperBound != 0) ? range.upperBound - 1 : range.upperBound
            let contentRange = "bytes \(lower)-\(upper)/\(streamLength)"
            let acceptRange = "bytes"

            statusCode = 206
            setValue(contentRange, forAdditionalHeader: "Content-Range")
            setValue(acceptRange, forAdditionalHeader: "Accept-Ranges")
            contentLength = UInt(range.count)
        } else {
            statusCode = 200
        }
        self.contentType = contentType
        cacheControlMaxAge = UInt(60 * 60 * 2)
        // TODO: lastModifiedDate = ...
        // TODO: setValue("", forAdditionalHeader: "Cache-Control")
    }

    /// Open the inputStream and set position to the beggining of the stream.
    ///
    /// - Throws: `WebServerResponseError.streamOpenFailed`,
    ///           `WebServerResponseError.invalidRange`.
    override open func open() throws {
        inputStream.open()
        guard inputStream.streamStatus == .open else {
            inputStream.close()
            throw WebServerResponseError.streamOpenFailed
        }
        guard let range = range else {
            throw WebServerResponseError.invalidRange
        }
        try inputStream.seek(offset: Int64(range.lowerBound), whence: .startOfFile)
    }

    /// Read data on the inputStream, up to bufferSize bytes.
    ///
    /// - Returns: The data that have been read.
    /// - Throws: `WebServerResponseError.invalidRange`.
    override open func readData() throws -> Data {
        guard let range = range else {
            throw WebServerResponseError.invalidRange
        }
        let len = min(bufferSize, range.count - Int(totalNumberOfBytesRead))
        // If nothing to read, return
        guard len > 0 else {
            return Data()
        }
        // Read
        let numberOfBytesRead = inputStream.read(&buffer, maxLength: len)
        guard numberOfBytesRead > 0 else {
            return Data()
        }
        totalNumberOfBytesRead += UInt64(numberOfBytesRead)
        return Data(bytes: buffer, count: numberOfBytesRead)
    }

    /// Closes the inputStream.
    override open func close() {
        inputStream.close()
    }
}


