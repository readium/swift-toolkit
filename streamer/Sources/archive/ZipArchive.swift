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


public class ZipArchive {
    
    internal var unzFile: unzFile
    internal var fileInfos: [String: ZipFileInfo] = [String: ZipFileInfo]()
    internal var currentFileOffset:UInt64?
    
    let bufferLength = 64 * 1024
    
    public var numberOfFiles: UInt64 {
        get {
            var globalInfo = unz_global_info64()
            memset(&globalInfo, 0, MemoryLayout<unz_global_info64>.size)
            let err = unzGetGlobalInfo64(unzFile, &globalInfo)
            if err != UNZ_OK {
                return 0
            }
            return globalInfo.number_entry
        }
    }

    public init?(url: URL) {
        // File manager
        let fileManager = FileManager.default
        
        // Check whether a zip file exists at path.
        let path = url.path
        
        if fileManager.fileExists(atPath: path) == false {
            return nil
        }
        
        if let unzFile = unzOpen64(path) {
            self.unzFile = unzFile
            
            /* Not needed for basic data reading operations
            do {
                try buildFilesList()
            } catch {
                return nil
            }
            */
        } else {
            return nil
        }
    }
    
    deinit {
        unzClose(unzFile)
    }

    func buildFilesList() throws {
        try goToFirstFile()
        repeat {
            let fileInfo = try infoOfCurrentFile()
            fileInfos[fileInfo.path] = fileInfo
        } while try goToNextFile()
    }
    
    func infoOfCurrentFile() throws -> ZipFileInfo {
        
        let fileNameMaxSize:UInt = 1024
        var fileInfo = unz_file_info64()
        let fileName = UnsafeMutablePointer<CChar>.allocate(capacity: Int(fileNameMaxSize))
        defer {
            free(fileName)
        }
        memset(&fileInfo, 0, MemoryLayout<unz_file_info64>.size)
        
        let err = unzGetCurrentFileInfo64(unzFile, &fileInfo, fileName, fileNameMaxSize, nil, 0, nil, 0)
        if err != UNZ_OK {
            throw ZipError.unzipFail
        }
        
        let path = String(cString: fileName)
        guard path.characters.count > 0 else {
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
    
    func goToFirstFile() throws {
        let err = unzGoToFirstFile(unzFile)
        if err != UNZ_OK {
            throw ZipError.unzipFail
        }
    }
    
    func goToNextFile() throws -> Bool {
        let err = unzGoToNextFile(unzFile)
        if err == UNZ_END_OF_LIST_OF_FILE {
            return false
        }
        if err != UNZ_OK {
            throw ZipError.unzipFail
        }
        return true
    }
    
    func locateFile(path: String) throws -> Bool {
        try goToFirstFile()
        let err = unzLocateFile(unzFile, path.cString(using: String.Encoding.utf8), nil)
        if err == UNZ_END_OF_LIST_OF_FILE {
            return false
        }
        if err != UNZ_OK {
            throw ZipError.unzipFail
        }
        return true
    }
    
    func readDataOfCurrentFile() throws -> Data {
        let fileInfo = try infoOfCurrentFile()
        
        let range = Range<UInt64>(uncheckedBounds: (lower: 0, upper: fileInfo.length))
        return try readDataOfCurrentFile(range: range)
        
        let err = unzOpenCurrentFile(unzFile)
        if err != UNZ_OK {
            throw ZipError.unzipFail
        }
        defer {
            unzCloseCurrentFile(unzFile)
        }
        
        //var buffer = Data(capacity: Int(fileInfo.length))
        var buffer = Array<CUnsignedChar>(repeating: 0, count: Int(fileInfo.length))
        let err2 = unzReadCurrentFile(unzFile, &buffer, UInt32(fileInfo.length))
        if err2 >= 0 {
            return Data(bytes: buffer)
        }
        throw ZipError.unzipFail
    }
    
    func readDataOfCurrentFile(range: Range<UInt64>) throws -> Data {
        if range.upperBound == UInt64.max {
            return try readDataOfCurrentFile()
        }
        
        assert(range.count < UInt64.Stride(UInt32.max), "Zip read data range too long")
        
        let err = unzOpenCurrentFile(unzFile)
        if err != UNZ_OK {
            throw ZipError.unzipFail
        }
        defer {
            unzCloseCurrentFile(unzFile)
        }
        
        let bufferLength = 1024 * 64
        let length = Int32(range.count)
        let offset = Int64(range.lowerBound)
        var buffer = Array<CUnsignedChar>(repeating: 0, count: bufferLength)
        var data = Data(capacity: Int(length))
        
        // Read the current file to the desired offset
        var offsetBytesRead:Int64 = 0
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
            offsetBytesRead += Int64(bytesRead)
        }
        
        // Read the current file and add it to the data
        var totalBytesRead:Int32 = 0
        while totalBytesRead < length {
            let bytesToRead = min(bufferLength, length - totalBytesRead)
            let bytesRead = unzReadCurrentFile(unzFile, &buffer, UInt32(bytesToRead))
            if bytesRead > 0 {
                totalBytesRead += bytesRead
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
    
    // MARK: Stream-like methods (experimental)
    
    /// note: the caller has to handle lock to access these methods
    
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
    
    public func seekCurrentFile(offset: UInt64) throws {
        let ioffset = Int64(offset)
        var buffer = Array<CUnsignedChar>(repeating: 0, count: bufferLength)
        
        // Read the current file to the desired offset
        var offsetBytesRead:Int64 = 0
        while offsetBytesRead < ioffset {
            let bytesToRead = min(bufferLength, ioffset - offsetBytesRead)
            // Data is discarded
            let bytesRead = unzReadCurrentFile(unzFile, &buffer, UInt32(bytesToRead))
            if bytesRead == 0 {
                break
            }
            if bytesRead != UNZ_OK {
                throw ZipError.unzipFail
            }
            offsetBytesRead += Int64(bytesRead)
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
