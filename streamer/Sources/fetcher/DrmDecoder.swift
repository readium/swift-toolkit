//
//  DrmDecoder.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri on 10/11/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import R2Shared

class DrmDecoder {

    /// <#Description#>
    ///
    /// - Parameters:
    ///   - input: <#input description#>
    ///   - publication: <#publication description#>
    ///   - path: <#path description#>
    ///   - drm: <#drm description#>
    /// - Returns: <#return value description#>
    static internal func decoding(_ input: SeekableInputStream,
                                  of publication: Publication,
                                  at path: String,
                                  with drm: Drm?) -> SeekableInputStream
    {
        // Check if the resource is encrypted.
        guard let drm = drm,
            let link = publication.link(withHref: path),
            let encryption = link.properties.encryption,
            let scheme = encryption.scheme else
        {
            return input
        }
        // Check that the encryption schemes of ressource and DRM are the same.
        guard scheme == drm.scheme.rawValue else {
            return input
        }
        // Decode the data and return a seekable input stream.
        return decypher(input, drm: drm)
    }

    /// <#Description#>
    ///
    /// - Parameters:
    ///   - input: <#input description#>
    ///   - drm: <#drm description#>
    /// - Returns: <#return value description#>
    static fileprivate func decypher(_ input: SeekableInputStream,
                                     drm: Drm) -> SeekableInputStream
    {
        guard let decypherFunc = drm.decypher else {
            return input
        }
        let bufferSize = Int(input.length)
        var buffer = Array<UInt8>(repeating: 0, count: bufferSize)

        input.open()
        
        let numberOfBytesRead = (input as InputStream).read(&buffer, maxLength: bufferSize)
        var data = Data(bytes: buffer, count: numberOfBytesRead)

        data = decypherFunc(data)

        let decypheredStream = DataInputStream(data: data)
        return decypheredStream
    }
}
