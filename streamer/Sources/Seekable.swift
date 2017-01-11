//
//  Seekable.swift
//  R2Streamer
//
//  Created by Olivier Körner on 11/01/2017.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation


/// Reference point for offset in seekable streams
public enum SeekWhence {
    /// The beginning of the file
    case startOfFile
    /// The end of the file
    case endOfFile
    /// the current position in the file
    case currentPosition
}


/// Protocol for seekable streams
public protocol Seekable {
    
    /**
     Set the current position in the data stream.
     
     - parameter offset: The offset to seek to.
     - parameter whence: Specifies the beginning, the end or the current position as the reference point for `offset`
    */
    func seek(offset: Int64, whence: SeekWhence) throws

}


class FileInputStream: InputStream, Seekable {
    public func seek(offset: Int64, whence: SeekWhence) throws {
        setProperty(offset, forKey: Stream.PropertyKey.fileCurrentOffsetKey)
    }
}
