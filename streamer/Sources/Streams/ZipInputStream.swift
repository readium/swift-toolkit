//
//  RDUnzipStream.swift
//  R2Streamer
//
//  Created by Olivier Körner on 11/01/2017.
//  Copyright © 2017 Readium. All rights reserved.
//

import UIKit
import minizip

extension ZipInputStream: Loggable {}

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
            if let o = zipArchive.currentFileOffset {
                return o
            }
            return 0
        }
    }

    override internal var hasBytesAvailable: Bool {
        get {
            return offset < _length
        }
    }

    init?(zipFilePath: String, path: String) {
        if let zipArchive = ZipArchive(url: URL(fileURLWithPath: zipFilePath)) {

            self.zipArchive = zipArchive
            fileInZipPath = path

            do {
                if try zipArchive.locateFile(path: fileInZipPath) {
                    let info = try zipArchive.infoOfCurrentFile()
                    _length = info.length
                } else {
                    return nil
                }
            } catch {
                return nil
            }

        } else {
            return nil
        }
    }

    init?(zipArchive: ZipArchive, path: String) {
        self.zipArchive = zipArchive
        fileInZipPath = path
        do {
            if try zipArchive.locateFile(path: fileInZipPath) {
                let info = try zipArchive.infoOfCurrentFile()
                _length = info.length
            } else {
                return nil
            }
        } catch {
            return nil
        }
        super.init()
    }

    override internal func open() {
        //objc_sync_enter(zipArchive)
        do {
            try zipArchive.openCurrentFile(path: fileInZipPath)
            _streamStatus = .open
        } catch {
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
        do {
            //Log.debug?.message("ZipInputStream \(fileInZipPath) read \(maxLength) bytes")
            let bytesRead = try zipArchive.readDataFromCurrentFile(buffer, maxLength: UInt64(maxLength))
            if Int(bytesRead) < maxLength {
                _streamStatus = .atEnd
            }
            return Int(bytesRead)
        } catch {
            log(level: .error, "ZipInputStream error \(error)")
            _streamStatus = .error
            _streamError = error
            return -1
        }
    }

    override internal func close() {
        //Log.debug?.message("ZipInputStream \(fileInZipPath) close")
        zipArchive.closeCurrentFile()
        //objc_sync_exit(zipArchive)
        _streamStatus = .closed
    }

    override internal func seek(offset: Int64, whence: SeekWhence) throws {

        assert(whence == .startOfFile, "Only seek from start of stream is supported for now.")
        assert(offset >= 0, "Since only seek from start of stream if supported, offset must be >= 0")

        log(level: .debug, "ZipInputStream \(fileInZipPath) offset \(offset)")
        do {
            try zipArchive.seekCurrentFile(offset: UInt64(offset))
        } catch {
            _streamStatus = .error
            _streamError = error
        }
    }

}
