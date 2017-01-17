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
    
    init?(fileAtPath: String) {
        guard FileManager.default.fileExists(atPath: fileAtPath) else {
            return nil
        }
        filePath = fileAtPath
        super.init()
    }
    
    override open func open() {
        fileHandle = FileHandle(forReadingAtPath: filePath)
    }
    
    override open func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        return -1
    }
    
    override open func close() {
        fileHandle?.closeFile()
    }

}
