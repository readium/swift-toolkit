//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared
import ReadiumGCDWebServer

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
@available(*, deprecated, message: "See the 2.5.0 migration guide to migrate the HTTP server")
open class WebServerResourceResponse: ReadiumGCDWebServerFileResponse {
    private let bufferSize = 32 * 1024

    private var resource: Resource
    private var range: Range<UInt64>?
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
    public init(resource: Resource, range: NSRange?, contentType: String) {
        self.resource = resource
        length = (try? resource.length.get()) ?? 0

        // If range is non nil - means it's not the first part (?)
        if let range = range {
//            WebServerResourceResponse.log(.debug, "Request range at \(range.location) remaining: \(range.length).")
            /// Return a range of what to read next (nothing, next part, whole data).
            func getNextRange(after range: NSRange,
                              forStreamOfLength streamLength: UInt64) -> Range<UInt64>
            {
                let newRange: Range<UInt64>

                if range.location == Int.max {
                    let len = min(UInt64(range.length), streamLength)

                    newRange = (streamLength - len) ..< streamLength
                } else if range.location < 0 {
                    // TODO: negative range location
                    // The whole data for now
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

        // Disable HTTP caching for publication resources, because it poses a security threat for protected
        // publications.
        setValue("no-cache, no-store, must-revalidate", forAdditionalHeader: "Cache-Control")
        setValue("no-cache", forAdditionalHeader: "Pragma")
        setValue("0", forAdditionalHeader: "Expires")

        // Response
        if let range = self.range {
            let lower = range.lowerBound
            let upper = (range.upperBound != 0) ? range.upperBound - 1 : range.upperBound
            let contentRange = "bytes \(lower)-\(upper)/\(length)"
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

    override open func open() throws {
        offset = range?.lowerBound ?? 0
    }

    /// Read a new chunk of data.
    override open func readData() throws -> Data {
        guard let range = range else {
            throw WebServerResponseError.invalidRange
        }
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
