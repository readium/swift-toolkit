//
//  DRMDecoder.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri on 10/11/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared


/// Decrypt DRM encrypted content.
class DRMDecoder: Loggable {

    /// Decode the given stream using DRM. If it fails, just return the
    /// stream unchanged.
    ///
    /// - Parameters:
    ///   - input: The input stream.
    ///   - resourceLink: The link represented by the stream.
    ///   - drm: The DRM object used for decryption.
    /// - Returns: The decrypted stream.
    static func decoding(_ input: SeekableInputStream, of resourceLink: Link, with drm: DRM?) -> SeekableInputStream {
        /// Check if the resource is encrypted.
        guard let drm = drm,
            let license = drm.license,
            let encryption = resourceLink.properties.encryption,
            let scheme = encryption.scheme,
            // Check that the encryption schemes of ressource and DRM are the same.
            scheme == drm.scheme.rawValue else
        {
            return input
        }
        
        let originalLength = encryption.originalLength
        let isDeflated = (encryption.compression == "deflate")
        let isCBC = (encryption.algorithm == "http://www.w3.org/2001/04/xmlenc#aes256-cbc")
        return (isDeflated || !isCBC)
            ? FullDRMInputStream(stream: input, link: resourceLink, license: license, originalLength: originalLength, isDeflated: isDeflated)
            : CBCDRMInputStream(stream: input, link: resourceLink, license: license, originalLength: originalLength)
    }

}
