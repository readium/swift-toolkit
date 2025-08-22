//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumFuzi
import ReadiumShared

/// A parser module which provide methods to parse encrypted XML elements.
final class EPUBEncryptionParser: Loggable {
    private let container: Container
    private let data: Data

    init(container: Container, data: Data) {
        self.container = container
        self.data = data
    }

    convenience init(container: Container) async throws {
        let path = "META-INF/encryption.xml"
        guard let data = try? await container.readData(at: AnyURL(string: path)!) else {
            throw EPUBParserError.missingFile(path: path)
        }
        self.init(container: container, data: data)
    }

    private lazy var document: ReadiumFuzi.XMLDocument? = {
        let document = try? ReadiumFuzi.XMLDocument(data: data)
        document?.defineNamespace(.enc)
        document?.defineNamespace(.ds)
        document?.defineNamespace(.comp)
        return document
    }()

    /// Parse the Encryption.xml EPUB file. It contains the informationg about encrypted resources and how to decrypt them.
    ///
    /// - Returns: A map between the resource `href` and the matching `Encryption`.
    func parseEncryptions() -> [RelativeURL: Encryption] {
        guard let document = document else {
            return [:]
        }

        var encryptions: [RelativeURL: Encryption] = [:]

        // Loop through <EncryptedData> elements..
        for encryptedDataElement in document.xpath("./enc:EncryptedData") {
            guard
                let algorithm = encryptedDataElement.firstChild(xpath: "enc:EncryptionMethod")?.attr("Algorithm"),
                let resourceURI = encryptedDataElement.firstChild(xpath: "enc:CipherData/enc:CipherReference")?.attr("URI")
                .flatMap(RelativeURL.init(epubHREF:))
                .map(\.normalized)
            else {
                continue
            }

            var scheme: String?
            var originalLength: Int?
            var compression: String?

            // LCP. Tag LCP protected resources.
            // FIXME: Move to ContentProtection?
            let keyInfoURI = encryptedDataElement.firstChild(xpath: "ds:KeyInfo/ds:RetrievalMethod")?.attr("URI")
            if keyInfoURI == "license.lcpl#/encryption/content_key" {
                scheme = "http://readium.org/2014/01/lcp"
            }
            // END LCP

            for encryptionProperty in encryptedDataElement.xpath("enc:EncryptionProperties/enc:EncryptionProperty") {
                // Check that we have a compression element, with originalLength, not empty.
                if let compressionElement = encryptionProperty.firstChild(xpath: "comp:Compression"),
                   let method = compressionElement.attr("Method"),
                   let length = compressionElement.attr("OriginalLength")
                {
                    originalLength = Int(length)
                    compression = (method == "8" ? "deflate" : "none")
                    break
                }
            }

            encryptions[resourceURI] = Encryption(
                algorithm: algorithm,
                compression: compression,
                originalLength: originalLength,
                scheme: scheme
            )
        }

        return encryptions
    }
}
