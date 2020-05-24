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
    
    private let container: Container
    private let data: Data
    private let drm: DRM?

    init(container: Container, data: Data, drm: DRM?) {
        self.container = container
        self.data = data
        self.drm = drm
    }
    
    convenience init(container: Container, drm: DRM?) throws {
        let path = "META-INF/encryption.xml"
        do {
            let data = try container.data(relativePath: path)
            self.init(container: container, data: data, drm: drm)
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
                var resourceURI = encryptedDataElement.firstChild(xpath:"enc:CipherData/enc:CipherReference")?.attr("URI")?.removingPercentEncoding else
            {
                continue
            }
            resourceURI = normalize(base: "/", href: resourceURI)

            var scheme: String?
            var originalLength: Int?
            var compression: String?
            var profile: String?
            
            // LCP. Tag LCP protected resources.
            let keyInfoURI = encryptedDataElement.firstChild(xpath: "ds:KeyInfo/ds:RetrievalMethod")?.attr("URI")
            if keyInfoURI == "license.lcpl#/encryption/content_key", drm?.brand == DRM.Brand.lcp {
                scheme = drm?.scheme.rawValue
            }
            
            // FIXME: Move that to ContentProtection
            if let licenseLCPLData = try? container.data(relativePath: "META-INF/license.lcpl"),
                let licenseLCPL = try? JSONSerialization.jsonObject(with: licenseLCPLData) as? [String: Any],
                let encryptionDict = licenseLCPL["encryption"] as? [String: Any]
            {
                profile = encryptionDict["profile"] as? String
            }
            // LCP END.

            for encryptionProperty in encryptedDataElement.xpath("enc:EncryptionProperties/enc:EncryptionProperty") {
                // Check that we have a compression element, with originalLength, not empty.
                if let compressionElement = encryptionProperty.firstChild(xpath:"comp:Compression"),
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
                profile: profile,
                scheme: scheme
            )
        }
        
        return encryptions
    }
    
}
