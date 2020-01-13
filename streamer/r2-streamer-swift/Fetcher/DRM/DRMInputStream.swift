//
//  DRMInputStream.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 04.07.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared


class DRMInputStream: SeekableInputStream, Loggable {
    
    let stream: SeekableInputStream
    let link: Link
    let license: DRMLicense
    let originalLength: Int?

    init(stream: SeekableInputStream, link: Link, license: DRMLicense, originalLength: Int?) {
        self.stream = stream
        self.link = link
        self.license = license
        self.originalLength = originalLength
        super.init()
    }
    
    
    // MARK: - Seekable
    
    override var length: UInt64 {
        return UInt64(originalLength ?? 0)
    }
    
    var _offset: UInt64 = 0
    override var offset: UInt64 { return _offset }
    
    override func seek(offset: Int64, whence: SeekWhence) throws {
        let length = Int64(self.length)
        switch whence {
        case .startOfFile:
            _offset = UInt64(min(offset, length))
        case .endOfFile:
            _offset = UInt64(min(length + offset, length))
        case .currentPosition:
            _offset = min(_offset + UInt64(offset), UInt64(length))
        }
    }
    
    
    // MARK: - Stream
    
    var _streamStatus: Stream.Status = .notOpen
    override var streamStatus: Stream.Status { return _streamStatus }
    
    private var _streamError: Error?
    override var streamError: Error? { return _streamError }
    
    func fail(with error: Error) {
        _streamStatus = .error
        _streamError = error
        log(.error, "\(type(of: self)): \(link.href): \(error.localizedDescription)")
    }
    
    override func open() {
        _streamStatus = .open
    }
    
    override func close() {
        _offset = 0
        _streamStatus = .notOpen
    }
    
    // MARK: - InputStream
    
    override var hasBytesAvailable: Bool {
        return offset < length
    }
    
    override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }
    
}
