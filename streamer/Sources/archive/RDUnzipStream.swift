//
//  RDUnzipStream.swift
//  R2Streamer
//
//  Created by Olivier Körner on 11/01/2017.
//  Copyright © 2017 Readium. All rights reserved.
//

import UIKit
import minizip



class RDUnzipStream: InputStream, RDSeekableInputStream {
    
    var unzFile: unzFile
    override var hasBytesAvailable: Bool {
        get {
            
        }
    }
    
    init(zipFilePath: String, path: String) throws {
        
    }
    
    override func open() {
        <#code#>
    }
    
    override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
        <#code#>
    }
    
    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        <#code#>
    }
    
    override func close() {
        <#code#>
    }
    
    func seek(offset: Int64, whence: SeekWhence) throws {
        
    }

}
