//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Minizip
import R2Shared
import UIKit

extension ZipInputStream: Loggable {}

/// Create a InputStream related to ONE file in the ZipArchive.
class ZipInputStream: SeekableInputStream {
    var zipArchive: ZipArchive
    var fileInZipPath: String

    private var _streamError: Error?
    override var streamError: Error? {
        _streamError
    }

    private var _streamStatus: Stream.Status = .notOpen
    override var streamStatus: Stream.Status {
        _streamStatus
    }

    private var _length: UInt64
    override var length: UInt64 {
        _length
    }

    override var offset: UInt64 {
        UInt64(zipArchive.currentFileOffset)
    }

    override var hasBytesAvailable: Bool {
        offset < _length
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
              let fileInfo = try? zipArchive.informationsOfCurrentFile()
        else {
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
              let fileInfo = try? zipArchive.informationsOfCurrentFile()
        else {
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
        false
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
