//
//  ResourceInputStream.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 31/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

/// Input stream to read a `Resource`'s content.
class ResourceInputStream: SeekableInputStream {
    
    private let resource: Resource
    
    init(resource: Resource, length: UInt64) {
        self.resource = resource
        self._length = length
        super.init()
    }
    
    private var _streamStatus: Stream.Status = .notOpen
    override var streamStatus: Stream.Status { _streamStatus }
    
    private var _streamError: Error?
    override var streamError: Error? { _streamError }
    
    private var _offset: UInt64 = 0
    override var offset: UInt64 { _offset }

    private var _length: UInt64
    override var length: UInt64 { _length }

    override var hasBytesAvailable: Bool { offset < length }
    
    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        guard hasBytesAvailable else {
            return 0
        }
        guard streamStatus == .open else {
            return -1
        }
        
        switch resource.read(range: offset..<(offset + UInt64(len))) {
        case .success(let data):
            assert(data.count <= len)
            _offset += UInt64(data.count)
            if !hasBytesAvailable {
                _streamStatus = .atEnd
            }
            data.copyBytes(to: buffer, count: min(data.count, len))
            return data.count

        case .failure(let error):
            _streamError = error
            _streamStatus = .error
            return -1
        }
    }
    
    override func seek(offset: Int64, whence: SeekWhence) throws {
        guard [.open, .atEnd].contains(streamStatus) else {
            return
        }
        
        let offset = UInt64(offset)
        switch whence {
        case .startOfFile:
            _offset = min(offset, length)
        case .endOfFile:
            _offset = max(0, length + min(0, offset))
        case .currentPosition:
            _offset = min(length, max(0, _offset + offset))
        }
    }
    
    override func open() {
        _streamStatus = .open
        _offset = 0
    }
    
    override func close() {
        // We don't close `resource` because other components might be using it.
        _streamStatus = .closed
    }
    
    override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }
    
}

extension Resource {
    
    func stream() -> ResourceResult<SeekableInputStream> {
        return length.map { length in
            ResourceInputStream(resource: self, length: length)
        }
    }
    
}
