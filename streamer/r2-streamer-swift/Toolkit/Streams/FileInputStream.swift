//
//  SeekableFileInputStream.swift
//  r2-streamer-swift
//
//  Created by Olivier Körner on 15/01/2017.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

/// FileInputStream errors
///
/// - read: An error while reading data from the fileHandle occured.
/// - fileHandleInitialisation: An error occured while initializing the fileHandle
/// - fileHandle: The fileHandle is not set or invalid.
public enum FileInputStreamError: Error {
    case read
    case fileHandleInitialisation
    case fileHandleUnset
}

extension FileInputStream: Loggable {}

internal class FileInputStream: SeekableInputStream {

    /// The path to the file opened by the stream
    private var filePath: String

    /// The file handle (== fd) of the file at path `filePath`
    private var fileHandle: FileHandle?

    ///
    private var _streamError: Error?
    override internal var streamError: Error? {
        get {
            return _streamError
        }
    }

    /// The status of the fileHandle
    private var _streamStatus: Stream.Status = .notOpen
    override internal var streamStatus: Stream.Status {
        get {
            return _streamStatus
        }
    }

    /// The size attribute of the file at `filePath`
    private var _length: UInt64
    override internal var length: UInt64 {
        get {
            return _length
        }
    }

    /// Current position in the stream.
    override internal var offset: UInt64 {
        get {
            return fileHandle?.offsetInFile ?? 0
        }
    }

    /// True when the current offset is not arrived the the end of the stream.
    override internal var hasBytesAvailable: Bool {
        get {
            return offset < _length
        }
    }

    // MARK: - Public methods.

    /// Initialize the object and the input stream meta data for file at
    /// `fileAtPath`.
    internal init?(fileAtPath: String) {
        // Does file `atFilePath` exists
        guard FileManager.default.fileExists(atPath: fileAtPath) else {
            FileInputStream.log(.error, "File not found: \(fileAtPath).")
            return nil
        }
        filePath = fileAtPath
        // Try to retrieve attributes of `fileAtPath`
        let attributes: [FileAttributeKey : Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: filePath)
        } catch {
            FileInputStream.log(.error, "Exception retrieving attrs for \(filePath): \(error)")
            return nil
        }
        // Verify the size attribute of the file at `fileAtPath`
        guard let fileSize = attributes[FileAttributeKey.size] as? UInt64 else {
            FileInputStream.log(.error, "Error accessing size attribute.")
            return nil
        }
        _length = fileSize
        super.init()
    }

    // MARK: - Open methods.

    /// Open a file handle (<=>fd) for file at path `filePath`.
    override internal func open() {
        fileHandle = FileHandle(forReadingAtPath: filePath)
        _streamStatus = .open
    }

    /// Close the file handle.
    override internal func close() {
        guard let fileHandle = fileHandle else {
            return
        }
        fileHandle.closeFile()
        _streamStatus = .closed
    }

    // TODO: to implement or delete ?
    override internal func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
                                     length len: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }


    // FIXME: Shouldn't we have smaller read in a loop?
    /// Read up to `maxLength` bytes from `fileHandle` and write them into `buffer`.
    ///
    /// - Parameters:
    ///   - buffer: The destination buffer.
    ///   - maxLength: The maximum number of bytes read.
    /// - Returns: Return the number of bytes read.
    override internal func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength: Int) -> Int {
        let readError = -1

        guard let fileHandle = fileHandle else {
            return readError
        }
        let data = fileHandle.readData(ofLength: maxLength)
        if data.count < maxLength {
            _streamStatus = .atEnd
        }
        data.copyBytes(to: buffer, count: data.count)
        return Int(data.count)
    }

    /// Moves the file pointer to the specified offset within the file.
    ///
    /// - Parameters:
    ///   - offset: The offset.
    ///   - whence: From which position.
    override internal func seek(offset: Int64, whence: SeekWhence) {
        assert(whence == .startOfFile, "Only seek from start of stream is supported for now.")
        assert(offset >= 0, "Since only seek from start of stream if supported, offset must be >= 0")

        guard let fileHandle = fileHandle else {
            _streamStatus = .error
            _streamError = FileInputStreamError.fileHandleUnset
            return
        }
        fileHandle.seek(toFileOffset: UInt64(offset))
    }
}
