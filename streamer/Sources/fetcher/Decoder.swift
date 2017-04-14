//
//  Decoder.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 4/13/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

extension Decoder: Loggable {}

/// Deobfuscation/Deencryption of resources.
internal class Decoder {
    /// Then algorythms handled by the Decoder.
    public var decodableAlgorithms = [
        "fontIdpf": "http://www.idpf.org/2008/embedding",
        "fontAdobe": "http://ns.adobe.com/pdf/enc#RC"
    ]

    fileprivate var decoders = [
        "fontIdpf": decodeIdpfFont,
        "fondAdobe": decodeAbobeFont
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
        return decodingFunction(self)(input, publication)
    }

    fileprivate func decodeIdpfFont(_ input: SeekableInputStream, _ publication: Publication) -> SeekableInputStream {
        //let key = getHashKey()
        return input
    }

    fileprivate func decodeAbobeFont(_ input: SeekableInputStream, _ publication: Publication) -> SeekableInputStream {
        return input
    }

}
