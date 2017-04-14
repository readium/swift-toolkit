//
//  Decoder.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 4/13/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import CryptoSwift

extension Decoder: Loggable {}

/// Deobfuscation/Deencryption of resources.
internal class Decoder {
    /// Then algorythms handled by the Decoder.
    public var decodableAlgorithms = [
        "fontIdpf": "http://www.idpf.org/2008/embedding",
        "fontAdobe": "http://ns.adobe.com/pdf/enc#RC"
    ]

    fileprivate var decoders = [
        "http://www.idpf.org/2008/embedding": decodeIdpfFont,
        "http://ns.adobe.com/pdf/enc#RC": decodeAbobeFont
    ]

    // TODO: is that ok to ignore if the decoder can't handler? as in go.
    /// If the data is Encrypted, see if the decoder can handle it, else ignore.
    internal func decode(_ input: SeekableInputStream,
                         of publication: Publication, at path: String) -> SeekableInputStream {
        // Check if the resource is encrypted.
        guard let link = publication.link(withHref: path),
            let encryption = link.properties.encryption,
            let algorithm = encryption.algorithm else
        {
            log(level: .info, "\(path) is not encrypted.")
            // FIXME: Throw error? or just ignore it?
            return input
        }
        // Check if the decoder can handle the encryption.
        guard decodableAlgorithms.values.contains(algorithm),
            let decodingFunction = decoders[link.properties.encryption!.algorithm!] else
        {
            log(level: .warning, "\(path)'s encrypted but decoder can't handle it")
            return input
        }

        // Decode data using the appropriate function found above.
        let nis = decodingFunction(self)(input, publication)
        // DBG
        if path == "fonts/sandome.obf.ttf" {
            print("TESTING")
        }
        return
    }

    fileprivate func decodeIdpfFont(_ input: SeekableInputStream, _ publication: Publication) -> SeekableInputStream {

        print("\(String(describing: publication.metadata.identifier))")
        guard let publicationIdentifier = publication.metadata.identifier else {
            log(level: .error, "Couldn't get the publication hashKey from identifier.")
            return input
        }
        // Generate the hashKey from the publicationIdentifier and store it into
        // a byte array.
        let publicationHashKey = publicationIdentifier.sha1().utf8.map{ UInt8($0) }
        // Fill a buffer with the inputStream data (content == the font file).
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(input.length))
        input.open()
        let read = input.read(buffer, maxLength: Int(input.length))
        input.close()
        // We only need to deobfuscate the 1040 first characters, or less
        // depending of the file. Unlikely to be smaller than 1040 though.
        let count = (read > 1040 ? 1040 : read)

        // Deobfuscate the first 1040 chars.
        var i = 0, j = 0
        while i < count {
            buffer[i] = buffer[i] ^ publicationHashKey[j]
            i += 1
            j += 1
            if j == 20 {
                j = 0
            }
        }
        // Create a Data object with the UInt8 buffer.
        let t = UnsafeBufferPointer.init(start: buffer, count: Int(input.length))
        let data = Data.init(buffer: t)
        print("\(data.description) and data count == \(data.count)")
        // Return a new Seekable InputStream created from the data.
        return DataInputStream.init(data: data)
    }

    fileprivate func decodeAbobeFont(_ input: SeekableInputStream, _ publication: Publication) -> SeekableInputStream {
        return input
    }

}
