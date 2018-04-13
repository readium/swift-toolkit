//
//  RDUnzipStream.swift
//  R2Streamer
//
//  Created by Olivier Körner on 11/01/2017.
//  Copyright © 2017 Readium. All rights reserved.
//

import UIKit
import Minizip

extension ZipInputStream: Loggable {}

/// Create a InputStream related to ONE file in the ZipArchive.
internal class ZipInputStream: SeekableInputStream {
    var zipArchive: ZipArchive
    var fileInZipPath: String

    private var _streamError: Error?
    override internal var streamError: Error? {
        get {
            return _streamError
        }
    }

    private var _streamStatus: Stream.Status = .notOpen
    override internal var streamStatus: Stream.Status {
        get {
            return _streamStatus
        }
    }

    private var _length: UInt64
    override internal var length: UInt64 {
        get {
            return _length
        }
    }

    override internal var offset: UInt64 {
        get {
            return UInt64(zipArchive.currentFileOffset)
        }
    }

    override internal var hasBytesAvailable: Bool {
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

    override internal func open() {
        //objc_sync_enter(zipArchive)
        do {
            try zipArchive.openCurrentFile()
            _streamStatus = .open
        } catch {
            print("ERROR: could not ZipArchive.openCurrentFile()")
            _streamStatus = .error
            _streamError = error
            //objc_sync_exit(zipArchive)
        }
    }

    override internal func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
                                     length len: UnsafeMutablePointer<Int>) -> Bool
    {
        return false
    }

    override internal func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength: Int) -> Int {
        //        guard _streamStatus == .open else  {
        //            print("Stream not open")
        //            return -1
        //        }
        //log(level: .debug, "\(fileInZipPath) read \(maxLength) bytes")
        let bytesRead = zipArchive.readDataFromCurrentFile(buffer, maxLength: UInt64(maxLength))
        if Int(bytesRead) < maxLength {
            _streamStatus = .atEnd
        }
        return Int(bytesRead)
    }

    override internal func close() {
        zipArchive.closeCurrentFile()
        //objc_sync_exit(zipArchive)
        _streamStatus = .closed
    }

    override internal func seek(offset: Int64, whence: SeekWhence) throws {
        assert(whence == .startOfFile, "Only seek from start of stream is supported for now.")
        assert(offset >= 0, "Since only seek from start of stream if supported, offset must be >= 0")

        //log(level: .debug, "ZipInputStream \(fileInZipPath) offset \(offset)")
        do {
            try zipArchive.seek(Int(offset))
        } catch {
            _streamStatus = .error
            _streamError = error
        }
    }

}
