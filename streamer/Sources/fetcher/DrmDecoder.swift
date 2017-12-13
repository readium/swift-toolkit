//
//  DrmDecoder.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri on 10/11/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import R2Shared

/// Decrypt DRM encrypted content.
class DrmDecoder {

    /// Decode the given stream using DRM. If it fails, just return the
    /// stream unchanged.
    ///
    /// - Parameters:
    ///   - input: The input stream.
    ///   - resourceLink: The link represented by the stream.
    ///   - drm: The DRM object used for decryption.
    /// - Returns: The decrypted stream.
    static internal func decoding(_ input: SeekableInputStream,
                                  of resourceLink: Link,
                                  with drm: Drm?) -> SeekableInputStream
    {
        /// Check if the resource is encrypted.
        guard let drm = drm,
            let encryption = resourceLink.properties.encryption,
            let scheme = encryption.scheme,
            // Check that the encryption schemes of ressource and DRM are the same.
            scheme == drm.scheme.rawValue,
            // Decode the data.
            var data = decipher(input, drm: drm) else
        {
            return input
        }
   
        /// If the ressource is compressed using deflate, inflate it.
        if resourceLink.properties.encryption?.compression == "deflate"
        {
            // Remove padding from data
            let padding = Int(data[data.count - 1])
            
            data = data.subdata(in: Range.init(uncheckedBounds: (0, data.count - padding)))
            guard let inflatedBuffer = data.inflate() else {
                print("Inflate error")
                return input
            }
            data = inflatedBuffer
        }
        /// Return a DataInputStream containing the decrypted data
        /// from initial stream.
        return DataInputStream.init(data: data)
    }

    /// Deciper a stream using the DRM object.
    ///
    /// - Parameters:
    ///   - input: The inpout stream.
    ///   - drm: The DRM object to use for decryption.
    /// - Returns: The decrypted Data.
    static fileprivate func decipher(_ input: SeekableInputStream,
                                     drm: Drm) -> Data?
    {
        // Check that the DRM object contain a decipherer.
        guard let drmLicense = drm.license else {
            return nil
        }
        // Transform stream into Data.
        let bufferSize = Int(input.length)
        var buffer = Array<UInt8>(repeating: 0, count: bufferSize)
        input.open()
        let numberOfBytesRead = (input as InputStream).read(&buffer, maxLength: bufferSize)
        let data = Data(bytes: buffer, count: numberOfBytesRead)
        input.close()

        // Convertion.
        do {
            return try drmLicense.decipher(data)
        } catch {
            return nil
        }
    }
}
