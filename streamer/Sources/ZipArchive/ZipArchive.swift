//
//  ZipArchive.swift
//  Zip
//
//  Created by Olivier Körner on 04/01/2017.
//  Copyright © 2017 Roy Marmelstein. All rights reserved.
//

import Foundation
import minizip

public struct ZipFileInfo {
    let path: String
    let length: UInt64
    let compressionLevel: Int
    let crypted: Bool
    let compressedLength: UInt64
    let date: Date?
    let crc32: UInt32
}

internal class ZipArchive {
    
    internal var unzFile: unzFile
    internal var fileInfos = [String: ZipFileInfo]()
    internal var currentFileOffset: UInt64?
    
    static let bufferLength = 64 * 1024
    
    public var numberOfFiles: UInt64 {
        get {
            var globalInfo = unz_global_info64()

            memset(&globalInfo, 0, MemoryLayout<unz_global_info64>.size)
            guard unzGetGlobalInfo64(unzFile, &globalInfo) == UNZ_OK else {
                return 0
            }
            return globalInfo.number_entry
        }
    }

    public init?(url: URL) {
        let fileManager = FileManager.default

        // Check that file exists at path and open it.
        guard fileManager.fileExists(atPath: url.path) != false,
            let unzFile = unzOpen64(url.path) else
        {
            return nil
        }
        self.unzFile = unzFile
    }
    
    deinit {
        unzClose(unzFile)
    }

    // Only used for CBZ so far.
    func buildFilesList() throws {
        try goToFirstFile()
        repeat {
            let fileInfo = try infoOfCurrentFile()
            fileInfos[fileInfo.path] = fileInfo
        } while try goToNextFile()
    }
    
    func infoOfCurrentFile() throws -> ZipFileInfo {
        let fileNameMaxSize = 1024
        var fileInfo = unz_file_info64()
        let fileName = UnsafeMutablePointer<CChar>.allocate(capacity: fileNameMaxSize)
        defer {
            free(fileName)
        }

        memset(&fileInfo, 0, MemoryLayout<unz_file_info64>.size)
        guard unzGetCurrentFileInfo64(unzFile, &fileInfo, fileName, UInt(fileNameMaxSize), nil, 0, nil, 0) == UNZ_OK else {
            throw ZipError.unzipFail
        }
        
        let path = String(cString: fileName)
        guard !path.characters.isEmpty else {
            throw ZipError.unzipFail
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
        
        let zipFileInfo = ZipFileInfo(path: path,
                                      length: fileInfo.uncompressed_size,
                                      compressionLevel: 0,
                                      crypted: crypted,
                                      compressedLength: fileInfo.compressed_size,
                                      date: date,
                                      crc32: UInt32(fileInfo.crc))
        return zipFileInfo
    }

    /// Set the current file to the first file of the archive.
    func goToFirstFile() throws {
        let ret = unzGoToFirstFile(unzFile)

        guard ret == UNZ_OK else {
            print("   > Error while going to first file.")
            throw ZipError.unzipFail
        }
    }

    /// Set the current file to next file.
    ///
    /// - Returns: True is there is a next file ?? false.
    func goToNextFile() throws -> Bool {
        let ret = unzGoToNextFile(unzFile)

        if ret == UNZ_END_OF_LIST_OF_FILE {
            return false
        }
        guard ret == UNZ_OK else {
            print("   > Error while going to next file.")
            throw ZipError.unzipFail
        }
        return true
    }
    
    func locateFile(path: String) throws -> Bool {
//        print("--< LOCATINGFILE \(path)... in \(unsafeBitCast(self, to: Int.self))")
//        defer {
//            print(" --> Done (for \(path)).")
//        }
        try goToFirstFile()

        let err = unzLocateFile(unzFile, path.cString(using: String.Encoding.utf8), nil)
        // File not found? file not accessible?
        if err == UNZ_END_OF_LIST_OF_FILE {
            print("locateFile -> File not found \(path)")
            return false
        }
        // Unknown error
        if err != UNZ_OK {
            throw ZipError.unzipFail
        }
        return true
    }
    
    func readDataOfCurrentFile() throws -> Data {
        let fileInfo = try infoOfCurrentFile()
        
        let range = Range<UInt64>(uncheckedBounds: (lower: 0, upper: fileInfo.length))
        return try readDataOfCurrentFile(range: range)
    }
    
    func readDataOfCurrentFile(range: Range<UInt64>) throws -> Data {
        if range.upperBound == UInt64.max {
            return try readDataOfCurrentFile()
        }
        
        //assert(range.count < UInt64.Stride(UInt32.max), "Zip read data range too long")
        
        let err = unzOpenCurrentFile(unzFile)
        if err != UNZ_OK {
            throw ZipError.unzipFail
        }
        defer {
            unzCloseCurrentFile(unzFile)
        }
        
        let bufferLength = 1024 * 64
        let length = range.count
        let offset = Int(range.lowerBound)
        var buffer = Array<CUnsignedChar>(repeating: 0, count: bufferLength)
        var data = Data(capacity: Int(length))
        
        // Read the current file to the desired offset
        var offsetBytesRead = 0
        while offsetBytesRead < offset {
            let bytesToRead = min(bufferLength, offset - offsetBytesRead)
            // Data is discarded
            let bytesRead = unzReadCurrentFile(unzFile, &buffer, UInt32(bytesToRead))
            if bytesRead == 0 {
                break
            }
            if bytesRead != UNZ_OK {
                throw ZipError.unzipFail
            }
            offsetBytesRead += Int(bytesRead)
        }
        
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
                throw ZipError.unzipFail
            }
        }
        return data
    }
    
    public func readData(path: String) throws -> Data {
        // TODO: find a cleaner and faster solution to prevent concurrent access to the zip file
        // https://www.cocoawithlove.com/blog/2016/06/02/threads-and-mutexes.html
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }
        
        if try locateFile(path: path) {
            return try readDataOfCurrentFile()
        } else {
            throw ZipError.fileNotFound
        }
    }

    /*
    public func readData(path: String, range: Range<UInt64>) throws -> Data {
        // TODO: find a cleaner and faster solution to prevent concurrent access to the zip file
        // https://www.cocoawithlove.com/blog/2016/06/02/threads-and-mutexes.html
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }
        
        if (try locateFile(path: path)) {
            return try readDataOfCurrentFile(range: range)
        } else {
            throw ZipError.fileNotFound
        }
    }
    */

    public func fileSize(path: String) throws -> UInt64 {
        if try locateFile(path: path) {
            let info = try infoOfCurrentFile()
            return info.length
        }
        throw ZipError.fileNotFound
    }

    public func fileSize() throws -> UInt64 {
        let info = try infoOfCurrentFile()
        return info.length
    }

    // MARK: Stream-like methods (experimental)

    // note: the caller has to handle lock to access these methods
    // if concurrent access to the resource is made

    public func openCurrentFile(path: String) throws {
        if try locateFile(path: path) {
            let err = unzOpenCurrentFile(unzFile)
            
            if err != UNZ_OK {
                throw ZipError.unzipFail
            }
            currentFileOffset = 0
        } else {
            throw ZipError.fileNotFound
        }
    }

    public func openCurrentFile() throws {
            let err = unzOpenCurrentFile(unzFile)

            if err != UNZ_OK {
                throw ZipError.unzipFail
            }
            currentFileOffset = 0
    }

    public func seekCurrentFile(offset: UInt64) throws {
        // TODO: Check if you can seek directly to offset in minizip instead of reading the bytes
        let ioffset = Int(offset)
        var buffer = Array<CUnsignedChar>(repeating: 0, count: ZipArchive.bufferLength)
        
        // Read the current file to the desired offset
        var offsetBytesRead: Int = 0
        while offsetBytesRead < ioffset {
            let bytesToRead = min(ZipArchive.bufferLength, ioffset - offsetBytesRead)
            // Data is discarded
            let bytesRead = unzReadCurrentFile(unzFile, &buffer, UInt32(bytesToRead))
            if bytesRead == 0 {
                break
            }
            if bytesRead > 0 {
                offsetBytesRead += Int(bytesRead)
            } else {
                throw ZipError.unzipFail
            }
        }
        currentFileOffset! += UInt64(offsetBytesRead)
    }
    
    public func readDataFromCurrentFile(_ buffer: UnsafeMutablePointer<UInt8>, maxLength: UInt64) throws -> UInt64 {
        
        assert(maxLength < UInt64(UInt32.max), "maxLength must be less than \(UInt32.max)")
        
        let bytesRead = unzReadCurrentFile(unzFile, buffer, UInt32(maxLength))
        if bytesRead >= 0 {
            currentFileOffset! += UInt64(bytesRead)
        } else {
            throw ZipError.unzipFail
        }
        return UInt64(bytesRead)
    }
    
    public func closeCurrentFile() {
        unzCloseCurrentFile(unzFile)
        currentFileOffset = nil
    }
    
}
