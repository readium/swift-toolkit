//
//  RDUnzipStream.swift
//  R2Streamer
//
//  Created by Olivier Körner on 11/01/2017.
//  Copyright © 2017 Readium. All rights reserved.
//

import UIKit
import minizip



public class ZipInputStream: SeekableInputStream {
    
    var zipArchive: ZipArchive
    var fileInZipPath: String
    
    private var _streamError: Error?
    override public var streamError: Error? {
        get {
            return _streamError
        }
    }
    private var _streamStatus: Stream.Status = .notOpen
    override public var streamStatus: Stream.Status {
        get {
            return _streamStatus
        }
    }
    
    override public var offset: UInt64 {
        get {
            if let o = zipArchive.currentFileOffset {
                return o
            }
            return 0
        }
    }
    
    private var _length: UInt64
    override public var length: UInt64 {
        get {
            return _length
        }
    }
    
    override public var hasBytesAvailable: Bool {
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
    }
    
    override public func open() {
        objc_sync_enter(zipArchive)
        do {
            try zipArchive.openCurrentFile(path: fileInZipPath)
            _streamStatus = .open
        } catch {
            _streamStatus = .error
            _streamError = error
            //objc_sync_exit(zipArchive)
        }
    }
    
    override public func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }
    
    override public func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength: Int) -> Int {
        do {
            NSLog("ZipInputStream \(fileInZipPath) read \(maxLength) bytes")
            let bytesRead = try zipArchive.readDataFromCurrentFile(buffer, maxLength: UInt64(maxLength))
            if Int(bytesRead) < maxLength {
                _streamStatus = .atEnd
            }
            return Int(bytesRead)
        } catch {
            NSLog("ZipInputStream error \(error)")
            _streamStatus = .error
            _streamError = error
        }
        return -1
    }
    
    override public func close() {
        NSLog("ZipInputStream \(fileInZipPath) close")
        zipArchive.closeCurrentFile()
        objc_sync_exit(zipArchive)
        _streamStatus = .closed
    }
    
    public override func seek(offset: Int64, whence: SeekWhence) throws {
        
        assert(whence == .startOfFile, "Only seek from start of stream is supported for now.")
        assert(offset >= 0, "Since only seek from start of stream if supported, offset must be >= 0")
        
        NSLog("ZipInputStream \(fileInZipPath) offset \(offset)")
        do {
            try zipArchive.seekCurrentFile(offset: UInt64(offset))
        } catch {
            _streamStatus = .error
            _streamError = error
        }
    }

}
