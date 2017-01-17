//
//  SeekableFileInputStream.swift
//  R2Streamer
//
//  Created by Olivier Körner on 15/01/2017.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation


open class FileInputStream: SeekableInputStream {
    
    private var filePath: String
    private var fileHandle: FileHandle?
    
    private var _streamError: Error?
    override open var streamError: Error? {
        get {
            return _streamError
        }
    }
    private var _streamStatus: Stream.Status = .notOpen
    override open var streamStatus: Stream.Status {
        get {
            return _streamStatus
        }
    }
    
    override public var offset: UInt64 {
        get {
            return fileHandle?.offsetInFile ?? 0
        }
    }
    
    private var _length: UInt64
    override public var length: UInt64 {
        get {
            return _length
        }
    }
    
    override open var hasBytesAvailable: Bool {
        get {
            return offset < _length
        }
    }
    
    init?(fileAtPath: String) {
        guard FileManager.default.fileExists(atPath: fileAtPath) else {
            return nil
        }
        filePath = fileAtPath
        if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath) {
            let fileSize = attrs[FileAttributeKey.size] as! UInt64
            _length = fileSize
        } else {
            // Something went wrong when getting the file size
            return nil
        }
        
        super.init()
    }
    
    override open func open() {
        fileHandle = FileHandle(forReadingAtPath: filePath)
        _streamStatus = .open
    }
    
    override open func close() {
        fileHandle?.closeFile()
        _streamStatus = .closed
    }

    override open func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }
    
    override open func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength: Int) -> Int {
        //NSLog("FileInputStream \(filePath) read \(maxLength) bytes")
        
        if let dataRead = fileHandle?.readData(ofLength: maxLength) {
            
            if dataRead.count < maxLength {
                _streamStatus = .atEnd
            }
            dataRead.copyBytes(to: buffer, count: dataRead.count)
            return Int(dataRead.count)
            
        } else {
            NSLog("FileInputStream error reading data")
            _streamStatus = .error
            _streamError = nil // TODO: Find proper error code
        }

        return -1
    }
    
    public override func seek(offset: Int64, whence: SeekWhence) throws {
        
        assert(whence == .startOfFile, "Only seek from start of stream is supported for now.")
        assert(offset >= 0, "Since only seek from start of stream if supported, offset must be >= 0")
        
        NSLog("FileInputStream \(filePath) offset \(offset)")
        do {
            fileHandle?.seek(toFileOffset: UInt64(offset))
        } catch {
            _streamStatus = .error
            _streamError = error
        }
    }
}
