//
//  RDUnzipStream.swift
//  R2Streamer
//
//  Created by Olivier Körner on 11/01/2017.
//  Copyright © 2017 Readium. All rights reserved.
//

import UIKit
import minizip



public class UnzipStream: InputStream {
    
    var unzFile: unzFile
    var fileInZipPath: String
    var fileInZipInfo: ZipFileInfo
    
    public var offset: UInt64 = 0
    public var length: UInt64?
    
    override public var hasBytesAvailable: Bool {
        get {
            return offset < totalLength!
        }
    }
    
    let readBufferSize = 64 * 1024
    
    init(zipFilePath: String, path: String) throws {
        if FileManager.default.fileExists(atPath: zipFilePath) == false {
            throw ZipError.fileNotFound
        }
        
        if let zf = unzOpen64(zipFilePath) {
            unzFile = zf
        } else {
            throw ZipError.zipFail
        }
        
        fileInZipPath = path
    }
    
    deinit {
        unzClose(unzFile)
    }
    
    internal func goToFirstFile() throws {
        let err = unzGoToFirstFile(unzFile)
        if err != UNZ_OK {
            throw ZipError.unzipFail
        }
    }
    
    internal func locateFile(_ path: String) throws -> Bool {
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
    
    internal func openFile(_ path: String) throws {
        if try locateFile(path) {
            let err = unzOpenCurrentFile(unzFile)
            if err != UNZ_OK {
                throw ZipError.unzipFail
            }
        } else {
            throw ZipError.fileNotFound
        }
    }
    
    internal func closeFile() {
        unzCloseCurrentFile(unzFile)
    }
    
    internal func infoOfCurrentFile() throws -> ZipFileInfo {
        
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
    
    override public func open() {
        do {
            try openFile(fileInZipPath)
        } catch {
            NSLog("Error opening zip input stream")
        }
    }
    
    override public func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }
    
    override public func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        <#code#>
    }
    
    override public func close() {
        closeFile()
    }
    
    public func seek(offset: Int64, whence: SeekWhence) throws {
        
        assert(whence == .startOfFile, "Only seek from start of file is supported for now.")
        
        try locateFile(fileInZipPath)
        
        let bufferLength = 1024 * 64
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
    }

}
