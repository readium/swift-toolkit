//
//  ZipArchive.swift
//  Zip
//
//  Created by Olivier Körner on 04/01/2017.
//  Copyright © 2017 Roy Marmelstein. All rights reserved.
//

import Foundation
import Minizip
import R2Shared

public struct ZipFileInfo {
    let path: String
    let length: UInt64
    let isCompressed: Bool
    let compressionLevel: Int
    let crypted: Bool
    let compressedLength: UInt64
    let date: Date?
    let crc32: UInt32
}

internal enum ZipArchiveError: Error {
    /// Minizip internal error.
    case minizipError
    /// A parameter passed to the minizip function wasn't accepted.
    case paramError
    /// The archive is currently busy or unusable.
    case archiveNotUsable
    /// The archive is corrupted.
    case badZipFile
    /// An error occured while reading the file at offset.
    case readError
    /// File not found in the archive.
    case fileNotFound
}

/// Wrapper around Minizip C lib. (Minizip uses Zlib)
internal class ZipArchive: Loggable {
    /// The minizip memory representation of the Archive.
    internal var unzFile: unzFile
    /// The informations about the Archive.
    internal var fileInfos = [String: ZipFileInfo]()
    internal let bufferLength = 1024 * 64

    /// The current offset position in the archive.
    internal var currentFileOffset: Int {
        get {
            return Int(unzGetOffset(unzFile))
        }
    }
    /// The total number of files in the archive.
    fileprivate var numberOfFiles: Int {
        get {
            var globalInfo = unz_global_info64()

            memset(&globalInfo, 0, MemoryLayout<unz_global_info64>.size)
            guard unzGetGlobalInfo64(unzFile, &globalInfo) == UNZ_OK else {
                return 0
            }
            return Int(globalInfo.number_entry)
        }
    }

    /// Initialize the object checking that the archive exists and opening it.
    internal init?(url: URL) {
        let fileManager = FileManager.default

        // Check that archives exists then open it.
        guard fileManager.fileExists(atPath: url.path) != false,
            let unzFile = unzOpen64(url.path)/*,
            try? goToFirestFile() Is that done by default? Tocheck*/ else
        {
            return nil
        }
        self.unzFile = unzFile
    }

    /// Close the archive on the object deallocation.
    deinit {
        unzClose(unzFile)
    }

    // Mark: - Internal Methods.

    /// Build the file list of the archive (Not done by default as it's only
    /// usef in the CBZ so far).
    internal func buildFilesList() throws {
        try goToFirstFile()
        repeat {
            let fileInfo = try informationsOfCurrentFile()
            
            fileInfos[fileInfo.path] = fileInfo
        } while try goToNextFile()
    }

    /// Reads the data of the file at offset.
    ///
    /// - Returns: The data of the file at offset.
    /// - Throws: 
    internal func readDataOfCurrentFile() throws -> Data {
        let fileInfo = try informationsOfCurrentFile()

        let range = Range<UInt64>(uncheckedBounds: (lower: 0, upper: fileInfo.length))
        return try readDataOfCurrentFile(range: range)
    }

    /// Reads the range of data from offset to range.
    ///
    /// - Parameter range:
    /// - Returns: <#return value description#>
    /// - Throws: <#throws value description#>
    fileprivate func readDataOfCurrentFile(range: Range<UInt64>) throws -> Data {
        let length = range.count
        var buffer = Array<CUnsignedChar>(repeating: 0, count: bufferLength)
        var data = Data(capacity: Int(length))

        /// Skip the first bytes of the file until lowerBound is reached.
        try seek(Int(range.lowerBound))
        // Read the current file and add it to the data
        var totalBytesRead = 0
        while totalBytesRead < length {
            let bytesToRead = min(bufferLength, length - totalBytesRead)
            let bytesRead = unzReadCurrentFile(unzFile, &buffer, UInt32(bytesToRead))
            if bytesRead > 0 {
                totalBytesRead += Int(bytesRead)
                data.append(buffer, count: Int(bytesRead))
            }
            else if bytesRead == 0 {
                break
            }
            else {
                throw ZipArchiveError.readError
            }
        }
        return data
    }

    /// <#Description#>
    ///
    /// - Parameters:
    ///   - buffer: <#buffer description#>
    ///   - maxLength: <#maxLength description#>
    /// - Returns: <#return value description#>
    /// - Throws: <#throws value description#>
    public func readDataFromCurrentFile(_ buffer: UnsafeMutablePointer<UInt8>, maxLength: UInt64) -> UInt64 {

        assert(maxLength < UInt64(UInt32.max), "maxLength must be less than \(UInt32.max)")

        let bytesRead = unzReadCurrentFile(unzFile, buffer, UInt32(maxLength))
        if bytesRead < 0 {
            log(.error, "Nothing to read")
        }
//        if bytesRead >= 0 {
//            currentFileOffset += UInt64(bytesRead)
//        } else {
//            throw ZipError.unzipFail
//        }
        return bytesRead > 0 ? UInt64(bytesRead) : 0
    }

    public func readData(path: String) throws -> Data {
        if locateFile(path: path) {
            try openCurrentFile()
            defer {
                closeCurrentFile()
            }
            return try readDataOfCurrentFile()
        } else {
            throw ZipArchiveError.fileNotFound
        }
    }

    // Mark: - Fileprivate Methods.

    /// Move the offset to the file at `path` in the archive.
    ///
    /// - Parameter path: The path of the file in the archive.
    /// - Returns: Return true if found, else false.
    /// - Throws: `ZipArchiveError.archiveNotUsable`,
    ///           `ZipArchiveError.paramError`.
    internal func locateFile(path: String) -> Bool {
        guard unzLocateFile(unzFile, path, nil) == UNZ_OK else {
            return false
        }
        return true
    }

    /// Moves offset to the first file of the archive.
    fileprivate func goToFirstFile() throws {
        guard unzGoToFirstFile(unzFile) == UNZ_OK else {
            throw ZipArchiveError.minizipError
        }
    }

    /// Moves offset to the next file of the archive.
    ///
    /// - Returns: Return false when there is no next file.
    /// - Throws:
    fileprivate func goToNextFile() throws -> Bool {
        let ret = unzGoToNextFile(unzFile)

        switch ret {
        case UNZ_END_OF_LIST_OF_FILE:
            return false
        case UNZ_OK:
            return true
        default:
            throw ZipArchiveError.minizipError
        }
    }

    /// UNZ Enum for the unzSeek function. Determining the offset reference.
    ///
    /// - set: Seek from beginning of file.
    /// - current: Seek from current position.
    /// - end: Set file pointer to EOF plus "offset"
    enum Origin: Int32 {
        case set = 0
        case current
        case end
    }

    /// Seek position x.
    ///
    /// - Parameter x: The number of bytes to advance the current offset to.
    internal func seek(_ offset: Int) throws {
        let isCompressed = try informationsOfCurrentFile().isCompressed
        // FIXME: https://github.com/readium/r2-shared-swift/issues/98
        if true || isCompressed {
            // Deflate is stream-based, so we need to read the bytes from the beginning and discard
            // them until we reach the offset.
            let ioffset = Int(offset)
            var buffer = Array<CUnsignedChar>(repeating: 0, count: bufferLength)

            // Read the current file to the desired offset
            var offsetBytesRead: Int = 0
            while offsetBytesRead < ioffset {
                let bytesToRead = min(bufferLength, ioffset - offsetBytesRead)
                // Data is discarded
                let bytesRead = unzReadCurrentFile(unzFile, &buffer, UInt32(bytesToRead))
                if bytesRead == 0 {
                    break
                }
                if bytesRead > 0 {
                    offsetBytesRead += Int(bytesRead)
                } else {
                    throw ZipArchiveError.minizipError
                }
            }
            
        } else {
            // For non-compressed entries, we can seek directly in the content.
            if unzseek(unzFile, offset, SEEK_CUR) != UNZ_OK {
                throw ZipArchiveError.minizipError
            }
        }
    }

    /// Open the file at offset.
    ///
    /// - Throws: `ZipArchiveError.paramError`,
    ///           `ZipArchiveError.badZipFile`,
    ///           `ZipArchiveError.minizipError`.
    internal func openCurrentFile() throws {
        let err = unzOpenCurrentFile(unzFile)

        switch err {
        case UNZ_PARAMERROR:
            throw ZipArchiveError.paramError
        case UNZ_BADZIPFILE:
            throw ZipArchiveError.badZipFile
        case UNZ_OK:
        break // Success.
        default: // UNZ_INTERNALERROR..
            throw ZipArchiveError.minizipError
        }
    }

    /// Close the currently opened file in the archive.
    public func closeCurrentFile() {
        unzCloseCurrentFile(unzFile)
    }

    /// Get the information about the file being at offset.
    ///
    /// - Returns: <#return value description#>
    /// - Throws: <#throws value description#>
    internal func informationsOfCurrentFile() throws -> ZipFileInfo {
        let fileNameMaxSize = 1024
        var fileInfo = unz_file_info64()
        let fileName = UnsafeMutablePointer<CChar>.allocate(capacity: fileNameMaxSize)
        defer {
            free(fileName)
        }

        memset(&fileInfo, 0, MemoryLayout<unz_file_info64>.size)
        guard unzGetCurrentFileInfo64(unzFile, &fileInfo, fileName, UInt(fileNameMaxSize), nil, 0, nil, 0) == UNZ_OK else {
            //throw ZipError.unzipFail
            throw ZipArchiveError.minizipError
        }
        let path = String(cString: fileName)
        guard !path.isEmpty else {
            throw ZipArchiveError.paramError
        }
        let crypted = ((fileInfo.flag & 1) != 0)
        let dateComponents = DateComponents(calendar: Calendar.autoupdatingCurrent,
                                            timeZone: TimeZone.autoupdatingCurrent,
                                            year: Int(fileInfo.tmu_date.tm_year),
                                            month: Int(fileInfo.tmu_date.tm_mon + 1),
                                            day: Int(fileInfo.tmu_date.tm_mday),
                                            hour: Int(fileInfo.tmu_date.tm_hour),
                                            minute: Int(fileInfo.tmu_date.tm_min),
                                            second: Int(fileInfo.tmu_date.tm_sec))
        let date = dateComponents.date
        let zipFileInfo = ZipFileInfo(
            path: path,
            length: fileInfo.uncompressed_size,
            isCompressed: fileInfo.compression_method != 0,
            compressionLevel: 0,
            crypted: crypted,
            compressedLength: fileInfo.compressed_size,
            date: date,
            crc32: UInt32(fileInfo.crc)
        )
        return zipFileInfo
    }

}
