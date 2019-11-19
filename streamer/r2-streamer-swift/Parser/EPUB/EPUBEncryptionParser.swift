//
//  EPUBEncryptionParser.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri, Mickaël Menu on 4/12/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import Fuzi
import R2Shared


/// A parser module which provide methods to parse encrypted XML elements.
final class EPUBEncryptionParser: Loggable {
    
    private let data: Data
    private let drm: DRM?

    init(data: Data, drm: DRM?) {
        self.data = data
        self.drm = drm
    }
    
    convenience init(container: Container, drm: DRM?) throws {
        let path = "META-INF/encryption.xml"
        do {
            let data = try container.data(relativePath: path)
            self.init(data: data, drm: drm)
        } catch {
            throw EPUBParserError.missingFile(path: path)
        }
    }

    private lazy var document: XMLDocument? = {
        let document = try? XMLDocument(data: data)
        document?.definePrefix("enc", forNamespace: "http://www.w3.org/2001/04/xmlenc#")
        document?.definePrefix("ds", forNamespace: "http://www.w3.org/2000/09/xmldsig#")
        document?.definePrefix("comp", forNamespace: "http://www.idpf.org/2016/encryption#compression")
        return document
    }()
    
    /// Parse the Encryption.xml EPUB file. It contains the informationg about encrypted resources and how to decrypt them.
    ///
    /// - Returns: A map between the resource `href` and the matching `EPUBEncryption`.
    func parseEncryptions() -> [String: EPUBEncryption] {
        guard let document = document else {
            return [:]
        }

        var encryptions: [String: EPUBEncryption] = [:]
        
        // Loop through <EncryptedData> elements..
        for encryptedDataElement in document.xpath("./enc:EncryptedData") {
            guard let algorithm = encryptedDataElement.firstChild(xpath: "enc:EncryptionMethod")?.attr("Algorithm"),
                var resourceURI = encryptedDataElement.firstChild(xpath:"enc:CipherData/enc:CipherReference")?.attr("URI")?.removingPercentEncoding else
            {
                continue
            }
            resourceURI = normalize(base: "/", href: resourceURI)

            var encryption = EPUBEncryption(algorithm: algorithm)

            // LCP. Tag LCP protected resources.
            let keyInfoURI = encryptedDataElement.firstChild(xpath: "ds:KeyInfo/ds:RetrievalMethod")?.attr("URI")
            if keyInfoURI == "license.lcpl#/encryption/content_key",
                drm?.brand == DRM.Brand.lcp
            {
                encryption.scheme = drm?.scheme.rawValue
            }
            // LCP END.

            for encryptionProperty in encryptedDataElement.xpath("enc:EncryptionProperties/enc:EncryptionProperty") {
                parseCompressionElement(from: encryptionProperty, to: &encryption)
            }
            encryptions[resourceURI] = encryption
        }
        
        return encryptions
    }

    /// Parse the <Compression> element.
    ///
    /// - Parameters:
    ///   - encryptionProperty: The EncryptionProperty element, parent of <Compression>.
    ///   - encryption: The EPUBEncryption structure to fill.
    private func parseCompressionElement(from encryptionProperty: XMLElement, to encryption: inout EPUBEncryption) {
        // Check that we have a compression element, with originalLength, not empty.
        guard let compressionElement = encryptionProperty.firstChild(xpath:"comp:Compression"),
            let method = compressionElement.attr("Method"),
            let originalLength = compressionElement.attr("OriginalLength") else
        {
            return
        }
        encryption.originalLength = Int(originalLength)
        encryption.compression = (method == "8" ? "deflate" : "none")
    }
    
}
