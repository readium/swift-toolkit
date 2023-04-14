//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import GCDWebServer
import R2Shared

/// Errors thrown by the `WebServerResourceResponse`
///
/// - streamOpenFailed: The stream is not open, stream.open() failed.
/// - invalidRange: The range queried is invalid.
enum WebServerResponseError: Error {
    case streamOpenFailed
    case invalidRange
}

/// The object containing the response's ressource data.
/// If the ressource to be served is too big, multiple responses will be created.
class ResourceResponse: GCDWebServerFileResponse, Loggable {
    private let bufferSize = 32 * 1024

    private var resource: Resource
    private var range: Range<UInt64>
    private let length: UInt64
    private var offset: UInt64 = 0
    private lazy var totalNumberOfBytesRead = UInt64(0)

    /// Initialise the WebServerRessourceResponse object, defining what will be
    /// served.
    ///
    /// - Parameters:
    ///   - resource: The publication resource to be served.
    ///   - range: The range of resource's data served previously, if any.
    ///   - contentType: The content-type of the response's ressource.
    init(resource: Resource, length: UInt64, range: NSRange?) {
        self.resource = resource
        self.length = length

        // If range is non nil - means it's not the first part (?)
        if let range = range {
            /// Return a range of what to read next (nothing, next part, whole data).
            func getNextRange(after range: NSRange,
                              forStreamOfLength streamLength: UInt64) -> Range<UInt64>
            {
                let newRange: Range<UInt64>

                if range.location == Int.max {
                    let len = min(UInt64(range.length), streamLength)

                    newRange = (streamLength - len) ..< streamLength
                } else if range.location < 0 {
                    // Negative range locations are not supported. We return
                    // the whole data for now.
                    newRange = 0 ..< streamLength
                } else {
                    let currentPosition = min(UInt64(range.location), streamLength)
                    let remainingLength = streamLength - currentPosition
                    let length: UInt64

                    if range.length == -1 {
                        length = remainingLength
                    } else {
                        length = min(UInt64(range.length), remainingLength)
                    }
                    newRange = currentPosition ..< (currentPosition + length)
                }
                return newRange
            }
            self.range = getNextRange(after: range,
                                      forStreamOfLength: length)
        } else /* nil */ {
            self.range = 0 ..< length
        }

        super.init()

        contentType = resource.link.type ?? ""

        // Disable HTTP caching for publication resources, because it poses a security threat for protected
        // publications.
        setValue("no-cache, no-store, must-revalidate", forAdditionalHeader: "Cache-Control")
        setValue("no-cache", forAdditionalHeader: "Pragma")
        setValue("0", forAdditionalHeader: "Expires")

        // Response
        let lower = self.range.lowerBound
        let upper = (self.range.upperBound != 0) ? self.range.upperBound - 1 : self.range.upperBound
        let contentRange = "bytes \(lower)-\(upper)/\(length)"
        let acceptRange = "bytes"

        statusCode = 206
        setValue(contentRange, forAdditionalHeader: "Content-Range")
        setValue(acceptRange, forAdditionalHeader: "Accept-Ranges")
        contentLength = UInt(self.range.count)
    }

    override open func open() throws {
        offset = range.lowerBound
    }

    /// Read a new chunk of data.
    override open func readData() throws -> Data {
        let len = min(bufferSize, range.count - Int(totalNumberOfBytesRead))
        // If nothing to read, return
        guard len > 0, offset < length else {
            return Data()
        }
        // Read
        let data = try resource.read(range: offset ..< (offset + UInt64(len))).get()
        totalNumberOfBytesRead += UInt64(data.count)
        offset += UInt64(data.count)
        return data
    }

    override open func close() {
        resource.close()
    }
}
