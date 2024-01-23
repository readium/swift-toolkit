//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import Fuzi
import R2Shared

/// A parser module which provide methods to parse encrypted XML elements.
final class EPUBEncryptionParser: Loggable {
    private let fetcher: Fetcher
    private let data: Data

    init(fetcher: Fetcher, data: Data) {
        self.fetcher = fetcher
        self.data = data
    }

    convenience init(fetcher: Fetcher) throws {
        let path = "/META-INF/encryption.xml"
        do {
            let data = try fetcher.readData(at: path)
            self.init(fetcher: fetcher, data: data)
        } catch {
            throw EPUBParserError.missingFile(path: path)
        }
    }

    private lazy var document: Fuzi.XMLDocument? = {
        let document = try? Fuzi.XMLDocument(data: data)
        document?.definePrefix("enc", forNamespace: "http://www.w3.org/2001/04/xmlenc#")
        document?.definePrefix("ds", forNamespace: "http://www.w3.org/2000/09/xmldsig#")
        document?.definePrefix("comp", forNamespace: "http://www.idpf.org/2016/encryption#compression")
        return document
    }()

    /// Parse the Encryption.xml EPUB file. It contains the informationg about encrypted resources and how to decrypt them.
    ///
    /// - Returns: A map between the resource `href` and the matching `Encryption`.
    func parseEncryptions() -> [String: Encryption] {
        guard let document = document else {
            return [:]
        }

        var encryptions: [String: Encryption] = [:]

        // Loop through <EncryptedData> elements..
        for encryptedDataElement in document.xpath("./enc:EncryptedData") {
            guard let algorithm = encryptedDataElement.firstChild(xpath: "enc:EncryptionMethod")?.attr("Algorithm"),
                  var resourceURI = encryptedDataElement.firstChild(xpath: "enc:CipherData/enc:CipherReference")?.attr("URI")?.removingPercentEncoding
            else {
                continue
            }
            resourceURI = HREF(resourceURI, relativeTo: "/").string

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
