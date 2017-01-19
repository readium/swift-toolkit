//
//  RDGCDServerResourceResponse.swift
//  R2Streamer
//
//  Created by Olivier Körner on 13/01/2017.
//  Copyright © 2017 Readium. All rights reserved.
//

import GCDWebServers


public enum WebServerResponseError: Error {
    case streamFailed
    case invalidRange
}


open class WebServerResourceResponse: GCDWebServerFileResponse {
    
    var inputStream: SeekableInputStream
    var range: Range<UInt64>
    var totalNumberOfBytesRead: UInt64 = 0
    var buffer:Array<UInt8>
    let bufferSize = 32 * 1024
    
    init(inputStream: SeekableInputStream, range: NSRange?, contentType: String) {
        buffer = Array<UInt8>(repeating: 0, count: bufferSize)
        self.inputStream = inputStream
        
        let totalLength = inputStream.length
        if let r = range {
            NSLog("Request range \(r.location)-\(r.length)")
            
            if r.location == Int.max {
                let l = min(UInt64(r.length), totalLength)
                self.range = Range<UInt64>(uncheckedBounds: (lower: totalLength - l, upper: totalLength))
            } else if r.location < 0 {
                // TODO: negative range location
                // The whole data for now
                self.range = Range<UInt64>(uncheckedBounds: (lower: 0, upper: totalLength))
            } else {
                let o = min(UInt64(r.location), totalLength)
                let l = (r.length == -1) ? (totalLength - o) : min(UInt64(r.length), totalLength - o)
                self.range = Range<UInt64>(uncheckedBounds: (lower: o, upper: o + l))
            }
            
            
        } else {
            self.range = Range<UInt64>(uncheckedBounds: (lower: 0, upper: totalLength))
        }
        
        super.init()
        
        if range != nil {
            statusCode = 206
            
            let lower = self.range.lowerBound
            let upper = self.range.upperBound - 1
            setValue("bytes \(lower)-\(upper)/\(totalLength)", forAdditionalHeader: "Content-Range")
            setValue("bytes", forAdditionalHeader: "Accept-Ranges")
        } else {
            statusCode = 200
        }

        self.contentType = contentType
        contentLength = UInt(self.range.count)
        
        cacheControlMaxAge = UInt(60 * 60 * 2)
        // TODO: lastModifiedDate = ...
        // TODO: setValue("", forAdditionalHeader: "Cache-Control")
    }
    
    override open func open() throws {
        inputStream.open()
        if (inputStream.streamStatus == .open) {
            try inputStream.seek(offset: Int64(range.lowerBound), whence: .startOfFile)
        } else {
            inputStream.close()
            throw WebServerResponseError.streamFailed
        }
    }
    
    override open func readData() throws -> Data {
        let len = min(bufferSize, Int64(range.count) - Int64(totalNumberOfBytesRead))
        let numberOfBytesRead = inputStream.read(&buffer, maxLength: len)
        if numberOfBytesRead > 0 {
            totalNumberOfBytesRead += UInt64(numberOfBytesRead)
            //NSLog("ResourceResponse read \(numberOfBytesRead) bytes")
            //NSLog("ResourceResponse \(range.lowerBound)-\(range.upperBound) / \(inputStream.length) : bytes read \(totalNumberOfBytesRead)")
            return Data(bytes: buffer, count: numberOfBytesRead)
        }
        return Data()
    }
    
    override open func close() {
        inputStream.close()
    }
}


