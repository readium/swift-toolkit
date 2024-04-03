//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

internal class DataInputStream: SeekableInputStream {
    let data: Data

    // MARK: - `Seekable` overrides.

    override internal var length: UInt64 {
        UInt64(data.count)
    }

    private var _offset: UInt64
    override internal var offset: UInt64 {
        _offset
    }

    override internal func seek(offset: Int64, whence: SeekWhence) throws {
        assert(whence == .startOfFile, "Only seek from start of stream is supported for now.")
        assert(offset >= 0, "Since only seek from start of stream if supported, offset must be >= 0")
        guard UInt64(offset) < length else {
            _streamStatus = .error
            return
        }
        _offset = UInt64(offset)
    }

    //

    override init(data: Data) {
        self.data = data
        _offset = 0
        super.init(data: data)
    }

    // MARK: - `InputStream` overrides

    /// The status of the fileHandle
    private var _streamStatus: Stream.Status = .notOpen
    override internal var streamStatus: Stream.Status {
        _streamStatus
    }

    /// to remove, useless.
    private var _streamError: Error?
    override internal var streamError: Error? {
        _streamError
    }

    override internal var hasBytesAvailable: Bool {
        offset < length
    }

    override internal func open() {
        _streamStatus = .open
    }

    override internal func close() {
        _offset = 0
        _streamStatus = .notOpen
    }

    override internal func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
                                     length len: UnsafeMutablePointer<Int>) -> Bool
    {
        false
    }

    override internal func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength: Int) -> Int {
        // Calculate readSize.
        let readSize = (maxLength > Int(length - offset) ? Int(length - offset) : maxLength)
        // Define range
        let start = data.index(0, offsetBy: Int(offset)) // Current position.
        let end = data.index(start, offsetBy: readSize) // End position
        let range = Range(uncheckedBounds: (start, end))

        data.copyBytes(to: buffer, from: range)
        _offset += UInt64(readSize)
        if _offset >= length {
            _streamStatus = .atEnd
        }
        return readSize
    }
}
