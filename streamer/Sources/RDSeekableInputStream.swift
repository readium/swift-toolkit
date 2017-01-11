//
//  RDSeekableInputStream.swift
//  R2Streamer
//
//  Created by Olivier Körner on 11/01/2017.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation


public enum SeekWhence {
    case startOfFile
    case endOfFile
    case currentPosition
}


public protocol RDSeekableInputStream {
    
    /**
     Seek to a location in the data stream.
     
     - parameter offset: The offset to seek to.
     - parameter whence: 
    */
    func seek(offset: Int64, whence: SeekWhence) throws

}


extension InputStream: RDSeekableInputStream {
    public func seek(offset: Int64, whence: SeekWhence) throws {
        setProperty(offset, forKey: Stream.PropertyKey.fileCurrentOffsetKey)
    }
}
