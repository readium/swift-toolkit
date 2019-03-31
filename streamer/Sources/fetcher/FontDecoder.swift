//
//  Decoder.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri on 4/13/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import R2Shared
import CryptoSwift

extension FontDecoder: Loggable {}

/// Deobfuscation/Deencryption of resources.
internal class FontDecoder {

    /// Then algorithms handled by the Decoder.
    static public var decodableAlgorithms = [
        "fontIdpf": "http://www.idpf.org/2008/embedding",
        "fontAdobe": "http://ns.adobe.com/pdf/enc#RC"
    ]

    /// Algorithm name and associated decoding function.
    static fileprivate var decoders = [
        "http://www.idpf.org/2008/embedding": ObfuscationLength.idpf,
        "http://ns.adobe.com/pdf/enc#RC": ObfuscationLength.adobe
    ]

    /// The number of characters obfuscated at the beggining of the font file.
    internal enum ObfuscationLength: Int {
        case adobe = 1024
        case idpf = 1040
    }

    /// Decode obfuscated font from a SeekableInputStream, if the encryption is 
    /// known.
    ///
    /// - Parameters:
    ///   - input: The InputStream containing the encrypted resource.
    ///   - publication: The publication where the encrypted resource does 
    ///                  originate from.
    ///   - path: The relative path of the resource inside of the publication.
    /// - Returns: The Inpustream containing the unencrypted resource.
    static internal func decoding(_ input: SeekableInputStream,
                                  of resourceLink: Link,
                                  _ publicationIdentifier: String?) -> SeekableInputStream
    {
        // If the publicationIdentifier is not accessible, no deobfuscation is
        // possible.
        guard let publicationIdentifier = publicationIdentifier else {
            log(.error, "Couldn't get the publication identifier.")
            return input
        }
        // Check if the resource is encrypted.
        guard let encryption = resourceLink.properties.encryption else {
            return input
        }
        let algorithm = encryption.algorithm
        // Check if the decoder can handle the encryption.
        guard decodableAlgorithms.values.contains(algorithm),
            let type = decoders[algorithm] else
        {
            return input
        }
        // Decode the data and return a seekable input stream.
        return decodingFont(input, publicationIdentifier, type)
    }

    /// Decode the given inputStream first X characters, depending of the obfu-
    /// -scation type.
    ///
    /// - Parameters:
    ///   - input: The input stream containing the data of an obfuscated font
    ///file.
    ///   - pubId: The associated publication Identifier.
    ///   - length: The ObfuscationLength depending of the obfuscation type.
    /// - Returns: The Deobfuscated SeekableInputStream.
    static internal func decodingFont(_ input: SeekableInputStream,
                             _ publicationIdentifier: String,
                             _ length: ObfuscationLength) -> DataInputStream
    {
        let publicationKey: [UInt8]
        
        
        // Generate the hashKey from the publicationIdentifier and store it into
        // a byte array.
        switch length {
        case .adobe:
            publicationKey = getHashKeyAdobe(publicationIdentifier: publicationIdentifier)
        case .idpf:
            publicationKey = hexaToBytes(publicationIdentifier.sha1())
        }
        // Create a buffer object.
        // Deobfuscate the first X characters, depending of the type of obf..
        let buffer = deobfuscate(input,
                                 publicationKey: publicationKey,
                                 obfuscationLength: length)
        // Create a Data object with the UInt8 buffer.
        let data = Data.init(buffer: buffer)
        // Return a new Seekable InputStream created from the data.
        return DataInputStream.init(data: data)
    }

    /// Receive an obfuscated InputStream and return a deabfuscated buffer of 
    /// UInt8.
    ///
    /// - Parameters:
    ///   - input: The Obfuscated `InputStream`.
    ///   - publicationKey: The publicationKey used to decode the X first
    ///                     characters.
    ///   - obfuscationLength: The number of characters obfuscated at the first
    ///                        of the file.
    /// - Returns: The UInt8 buffer containing the déobfuscated data.
    static fileprivate func deobfuscate(_ input: SeekableInputStream,
                                 publicationKey: [UInt8],
                                 obfuscationLength: ObfuscationLength) -> UnsafeBufferPointer<UInt8>
    {
        // Allocate a buffer with the inputStream data at pointer.
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(input.length))

        // Fill the buffer with the font file content.
        input.open()
        let readSize = input.read(buffer, maxLength: Int(input.length))
        input.close()
        // TODO: Add a verif that read is > 0 or throw, then change the bottom line input.length to readsize.

        // We only need to deobfuscate the 1024 first characters, or less
        // depending of the file. Unlikely to be smaller than 1024 though.
        let count = (readSize > obfuscationLength.rawValue ? obfuscationLength.rawValue : readSize)
        // Deobfuscate the first x chars.
        let pubKeyLength = publicationKey.count
        var i = 0

        while i < count {
            buffer[i] = buffer[i] ^ publicationKey[i % pubKeyLength]
            i += 1
        }
        return UnsafeBufferPointer.init(start: buffer, count: Int(input.length))//readsize) // TODO: change that
    }

    /// Generate the Hashkey used to salt the 1024 starting character of the
    /// Adobe font files.
    ///
    /// - Parameter pubId: The publication Identifier.
    /// - Returns: The key's bytes array.
    static fileprivate func getHashKeyAdobe(publicationIdentifier pubId: String) -> [UInt8] {
        // Clean the publicationIdentifier.
        var cleanPubId = pubId.replacingOccurrences(of: "urn:uuid:", with: "")
        cleanPubId = cleanPubId.replacingOccurrences(of: "-", with: "")

        return hexaToBytes(cleanPubId)
    }

    /// Convert hexadecimal String to Bytes (UInt8) array.
    ///
    /// - Parameter hexa: The hexadecimal String.
    /// - Returns: The key's bytes array.
    static fileprivate func hexaToBytes(_ hexa: String) -> [UInt8] {
        var position = hexa.startIndex

        return (0..<hexa.count / 2).compactMap { _ in
            defer { position = hexa.index(position, offsetBy: 2) }

            return UInt8(hexa[position...hexa.index(after: position)], radix: 16)
        }
    }
}
