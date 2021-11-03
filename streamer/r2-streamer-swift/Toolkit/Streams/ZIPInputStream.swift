//
//  RDUnzipStream.swift
//  r2-streamer-swift
//
//  Created by Olivier Körner on 11/01/2017.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import Minizip
import R2Shared

extension ZipInputStream: Loggable {}

/// Create a InputStream related to ONE file in the ZipArchive.
class ZipInputStream: SeekableInputStream {
    var zipArchive: ZipArchive
    var fileInZipPath: String

    private var _streamError: Error?
    override var streamError: Error? {
        get {
            return _streamError
        }
    }

    private var _streamStatus: Stream.Status = .notOpen
    override var streamStatus: Stream.Status {
        get {
            return _streamStatus
        }
    }

    private var _length: UInt64
    override var length: UInt64 {
        return _length
    }

    override var offset: UInt64 {
        return UInt64(zipArchive.currentFileOffset)
    }

    override var hasBytesAvailable: Bool {
        get {
            return offset < _length
        }
    }

    init?(zipFilePath: String, path: String) {
        // New ZipArchive for archive at `zipFilePath`.
        guard let zipArchive = ZipArchive(url: URL(fileURLWithPath: zipFilePath)) else {
            return nil
        }
        self.zipArchive = zipArchive
        fileInZipPath = path
        // Check if the file exists in the archive.
        guard zipArchive.locateFile(path: fileInZipPath),
            let fileInfo = try? zipArchive.informationsOfCurrentFile() else
        {
            return nil
        }
        _length = fileInfo.length
        super.init()
    }

    init?(zipArchive: ZipArchive, path: String) {
        self.zipArchive = zipArchive
        fileInZipPath = path
        // Check if the file exists in the archive.
        guard zipArchive.locateFile(path: fileInZipPath),
            let fileInfo = try? zipArchive.informationsOfCurrentFile() else
        {
            return nil
        }

        _length = fileInfo.length
        super.init()
    }

    override func open() {
        do {
            try zipArchive.openCurrentFile()
            _streamStatus = .open
        } catch {
            log(.error, "Could not ZipArchive.openCurrentFile()")
            _streamStatus = .error
            _streamError = error
        }
    }

    override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
                                     length len: UnsafeMutablePointer<Int>) -> Bool
    {
        return false
    }

    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength: Int) -> Int {
        let bytesRead = zipArchive.readDataFromCurrentFile(buffer, maxLength: UInt64(maxLength))
        if Int(bytesRead) < maxLength {
            _streamStatus = .atEnd
        }
        return Int(bytesRead)
    }

    override func close() {
        zipArchive.closeCurrentFile()
        _streamStatus = .closed
    }

    override func seek(offset: Int64, whence: SeekWhence) throws {
        assert(whence == .startOfFile, "Only seek from start of stream is supported for now.")
        assert(offset >= 0, "Since only seek from start of stream if supported, offset must be >= 0")
        
        do {
            try zipArchive.seek(Int(offset))
        } catch {
            _streamStatus = .error
            _streamError = error
        }
    }

}
