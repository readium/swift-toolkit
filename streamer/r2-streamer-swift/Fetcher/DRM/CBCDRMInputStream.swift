//
//  CBCDRMInputStream.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 04.07.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


private let AESBlockSize: Int64 = 16  // bytes

/// A DRM input stream to read content encrypted with the CBC algorithm. Support random access for byte range requests.
final class CBCDRMInputStream: DRMInputStream {
    
    enum Error: Swift.Error {
        case invalidStream
        case emptyDecryptedData
        case readFailed
        case decryptionFailed
    }
    
    private lazy var plainTextSize: Int64 = {
        guard stream.length >= 2 * AESBlockSize else {
            fail(with: Error.invalidStream)
            return 0
        }
        
        do {
            let readPosition = Int64(stream.length) - 2 * AESBlockSize
            let bufferSize = 2 * AESBlockSize
            var buffer = Array<UInt8>(repeating: 0, count: Int(bufferSize))
            
            stream.open()
            try stream.seek(offset: readPosition, whence: .startOfFile)
            let numberOfBytesRead = stream.read(&buffer, maxLength: Int(bufferSize))
            let data = Data(bytes: buffer, count: numberOfBytesRead)
            stream.close()
            
            guard let decryptedData = try license.decipher(data) else {
                fail(with: Error.emptyDecryptedData)
                return 0
            }
            
            return Int64(stream.length)
                - AESBlockSize  // Minus IV or previous block
                - (AESBlockSize - Int64(decryptedData.count)) % AESBlockSize  // Minus padding part
            
        } catch {
            fail(with: error)
            return 0
        }
    }()
    
    override var length: UInt64 {
        return UInt64(plainTextSize)
    }
    
    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        let offset = Int64(self.offset)
        let len = min(Int64(len), Int64(length) - offset)
        guard hasBytesAvailable, len > 0 else {
            return 0 // EOF
        }

        // Get offset result offset in the block.
        let blockOffset = offset % AESBlockSize
        // For beginning of the cipher text, IV used for XOR.
        // For cipher text in the middle, previous block used for XOR.
        let readPosition = offset - blockOffset
        
        // Count blocks to read.
        // First block for IV or previous block to perform XOR.
        var blocksCount: Int64 = 1
        var bytesInFirstBlock: Int64 = (AESBlockSize - blockOffset) % AESBlockSize
        if len < bytesInFirstBlock {
            bytesInFirstBlock = 0
        }
        if bytesInFirstBlock > 0 {
            blocksCount += 1
        }
        
        blocksCount += (len - bytesInFirstBlock) / AESBlockSize
        if (len - bytesInFirstBlock) % AESBlockSize != 0 {
            blocksCount += 1
        }
        
        // Read data from the stream
        var data: Data
        do {
            let bufferSize = blocksCount * AESBlockSize
            var buffer = Array<UInt8>(repeating: 0, count: Int(bufferSize))
            stream.open()
            try stream.seek(offset: Int64(readPosition), whence: .startOfFile)
            let numberOfBytesRead = stream.read(&buffer, maxLength: Int(bufferSize))
            assert(numberOfBytesRead >= 0)
            data = Data(bytes: buffer, count: numberOfBytesRead)
            stream.close()
            
        } catch {
            fail(with: Error.readFailed)
            return -1
        }
        
        do {
            guard let decryptedData = try license.decipher(data) else {
                fail(with: Error.emptyDecryptedData)
                return -1
            }
            data = decryptedData
        } catch {
            fail(with: Error.decryptionFailed)
            return -1
        }
        
        // TODO: Double check if there is a different way to remove padding from HTML resources only.
        if link.mediaType?.isHTML == true {
          let padding = Int(data[data.count - 1])
          data = data.subdata(in: Range(uncheckedBounds: (0, data.count - padding)))
        }

        if data.count > len {
            data = data[0..<min(data.count, Int(len))]
        }
        data.copyBytes(to: buffer, count: data.count)
        _offset += UInt64(data.count)
        if _offset >= length {
            _streamStatus = .atEnd
        }
        return data.count
    }
    
}
