//
//  LCPDecryptor.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 30/05/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

private let AESBlockSize: UInt64 = 16  // bytes

/// Decrypts a resource protected with LCP.
final class LCPDecryptor {
    
    enum Error: Swift.Error {
        case emptyDecryptedData
        case invalidCBCData
        case inflateFailed
    }
    
    var license: DRMLicense?
    
    private let scheme: String

    init() {
        self.scheme = DRM.Scheme.lcp.rawValue
    }
    
    convenience init?(drm: DRM?) {
        guard drm?.brand == .lcp else {
            return nil
        }
        self.init()
    }
    
    func decrypt(resource: Resource) -> Resource {
        // Checks if the resource is encrypted and whether the encryption schemes of the resource
        // and the DRM license are the same.
        let link = resource.link
        guard let encryption = link.properties.encryption, encryption.scheme == self.scheme else {
            return resource
        }
        guard let license = license else {
            return FailureResource(link: link, error: .forbidden)
        }
        
        if link.isDeflated || !link.isCbcEncrypted {
            return FullLCPResource(resource, license: license).cached()
        } else {
            return CBCLCPResource(resource, license: license)
        }
    }
    
    /// A  LCP resource that is read, decrypted and cached fully before reading requested ranges.
    ///
    /// Can be used when it's impossible to map a read range (byte range request) to the encrypted
    /// resource, for example when the resource is deflated before encryption.
    private class FullLCPResource: TransformingResource {
        
        private let license: DRMLicense
        
        init(_ resource: Resource, license: DRMLicense) {
            self.license = license
            super.init(resource)
        }
        
        override func transform(_ data: ResourceResult<Data>) -> ResourceResult<Data> {
            return license.decryptFully(data: data, isDeflated: resource.link.isDeflated)
        }
        
        override var length: ResourceResult<UInt64> {
            // Uses `originalLength` or falls back on the actual decrypted data length.
            resource.link.properties.encryption?.originalLength.map { .success(UInt64($0)) }
                ?? super.length
        }

    }
    
    /// A LCP resource used to read content encrypted with the CBC algorithm.
    ///
    /// Supports random access for byte range requests, but the resource MUST NOT be deflated.
    private class CBCLCPResource: ProxyResource {
        
        private let license: DRMLicense
        
        init(_ resource: Resource, license: DRMLicense) {
            assert(!resource.link.isDeflated)
            assert(resource.link.isCbcEncrypted)
            self.license = license
            super.init(resource)
        }
        
        private lazy var plainTextSize: ResourceResult<UInt64> = {
            return resource.length.tryFlatMap { length in
                guard length >= 2 * AESBlockSize else {
                    throw LCPDecryptor.Error.invalidCBCData
                }
                
                let readPosition = length - 2 * AESBlockSize
                return resource.read(range: readPosition..<length)
                    .tryMap { encryptedData in
                        guard let data = try license.decipher(encryptedData) else {
                            throw LCPDecryptor.Error.emptyDecryptedData
                        }
                        
                        return length
                            - AESBlockSize  // Minus IV or previous block
                            - (AESBlockSize - UInt64(data.count)) % AESBlockSize  // Minus padding part
                }
            }
        }()
        
        override func read(range: Range<UInt64>?) -> ResourceResult<Data> {
            guard let range = range else {
                return license.decryptFully(data: resource.read(), isDeflated: resource.link.isDeflated)
            }
            
            return resource.length.tryFlatMap { totalLength in
                let length = range.upperBound - range.lowerBound
                let blockPosition = range.lowerBound % AESBlockSize
                
                // For beginning of the cipher text, IV used for XOR.
                // For cipher text in the middle, previous block used for XOR.
                let readPosition = range.lowerBound - blockPosition
                
                // Count blocks to read.
                // First block for IV or previous block to perform XOR.
                var blocksCount: UInt64 = 1
                var bytesInFirstBlock = (AESBlockSize - blockPosition) % AESBlockSize
                if (length < bytesInFirstBlock) {
                    bytesInFirstBlock = 0
                }
                if (bytesInFirstBlock > 0) {
                    blocksCount += 1
                }
                
                blocksCount += (length - bytesInFirstBlock) / AESBlockSize
                if (length - bytesInFirstBlock) % AESBlockSize != 0 {
                    blocksCount += 1
                }
                
                let readSize = blocksCount * AESBlockSize
                
                return resource.read(range: readPosition..<(readPosition + readSize))
                    .tryMap { encryptedData in
                        guard var data = try license.decipher(encryptedData) else {
                            throw LCPDecryptor.Error.emptyDecryptedData
                        }
                        
                        if (data.count > length) {
                            data = data[0..<length]
                        }
                        
                        return data
                }
            }
        }
        
        override var length: ResourceResult<UInt64> { plainTextSize }
        
    }
    
}

private extension DRMLicense {
    
    func decryptFully(data: ResourceResult<Data>, isDeflated: Bool) -> ResourceResult<Data> {
        return data.tryMap {
            // Decrypts the resource.
            guard var data = try self.decipher($0) else {
                throw LCPDecryptor.Error.emptyDecryptedData
            }
            
            // Removes the padding.
            let padding = Int(data[data.count - 1])
            data = data[0..<(data.count - padding)]
            
            // If the ressource was compressed using deflate, inflate it.
            if isDeflated {
                guard let inflatedData = data.inflate() else {
                    throw LCPDecryptor.Error.inflateFailed
                }
                data = inflatedData
            }
            
            return data
        }
    }
    
}

private extension Link {
    
    var isDeflated: Bool {
        properties.encryption?.compression?.lowercased() == "deflate"
    }
    
    var isCbcEncrypted: Bool {
        properties.encryption?.algorithm == "http://www.w3.org/2001/04/xmlenc#aes256-cbc"
    }
    
}
