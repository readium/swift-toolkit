//
//  EncryptionParser.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri on 4/12/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import R2Shared
import AEXML

extension EncryptionParser: Loggable {}

/// A parser module which provide methods to parse encrypted XML elements.
final public class EncryptionParser {
    
    private let data: Data
    private let drm: DRM?
    
    init(data: Data, drm: DRM?) {
        self.data = data
        self.drm = drm
    }
    
    private lazy var document: AEXMLDocument? = {
        var options = AEXMLOptions()
        // Deactivates namespaces so that we don't have to look for both enc:EncryptedData, and EncryptedData, for example.
        options.parserSettings.shouldProcessNamespaces = true
        return try? AEXMLDocument(xml: data, options: options)
    }()

//    private lazy var document: XMLDocument? = {
//        let document = try? XMLDocument(data: data)
////        document?.definePrefix("html", defaultNamespace: "http://www.w3.org/1999/xhtml")
//        return document
//    }()
    
    /// Parse the Encryption.xml EPUB file. It contains the informationg about encrypted resources and how to decrypt them.
    ///
    /// - Returns: A map between the resource `href` and the matching `EPUBEncryption`.
    lazy var encryptions: [String: EPUBEncryption] = {
        guard let document = document,
            let encryptedDataElements = document["encryption"]["EncryptedData"].all else
        {
            return [:]
        }
        
        var encryptions: [String: EPUBEncryption] = [:]
        
        // Loop through <EncryptedData> elements..
        for encryptedDataElement in encryptedDataElements {
            guard let algorithm = encryptedDataElement["EncryptionMethod"].attributes["Algorithm"],
                var resourceURI = encryptedDataElement["CipherData"]["CipherReference"].attributes["URI"] else
            {
                continue
            }
            resourceURI = normalize(base: "/", href: resourceURI)
            
            var encryption = EPUBEncryption(algorithm: algorithm)
            
            // LCP. Tag LCP protected resources.
            let keyInfoUri = encryptedDataElement["KeyInfo"]["RetrievalMethod"].attributes["URI"]
            if keyInfoUri == "license.lcpl#/encryption/content_key",
                drm?.brand == DRM.Brand.lcp
            {
                encryption.scheme = drm?.scheme.rawValue
            }
            // LCP END.
            
            parseEncryptionProperties(from: encryptedDataElement, to: &encryption)
            encryptions[resourceURI] = encryption
        }
        
        return encryptions
    }()
    
    /// Parse the <EncryptionProperties> containing <EncryptionProperty> child
    /// elements in order to fill the `EPUBEncryption`.
    ///
    /// - Parameters:
    ///   - encryptedDataElement: The <EncryptedData> parent element.
    ///   - encryption: The `EPUBEncryption` structure to fill.
    private func parseEncryptionProperties(from encryptedDataElement: AEXMLElement, to encryption: inout EPUBEncryption) {
        guard let encryptionProperties = encryptedDataElement["EncryptionProperties"]["EncryptionProperty"].all else {
            return
        }
        //
        for encryptionProperty in encryptionProperties {
            parseCompressionElement(from: encryptionProperty, to: &encryption)
        }
    }

    /// Parse the <Compression> element.
    ///
    /// - Parameters:
    ///   - encryptionProperty: The EncryptionProperty element, parent of
    ///                         <Compression>.
    ///   - encryption: The EPUBEncryption structure to fill.
    private func parseCompressionElement(from encryptionProperty: AEXMLElement, to encryption: inout EPUBEncryption) {
        // Check that we have a compression element, with originalLength, not empty.
        guard let compressionElement = encryptionProperty["Compression"].first,
            let originalLength = compressionElement.attributes["OriginalLength"],
            !originalLength.isEmpty else
        {
            return
        }
        encryption.originalLength = Int(originalLength)
        // Find the method attribute.
        guard let method = compressionElement.attributes["Method"] else {
            return
        }
        encryption.compression = (method == "8" ? "deflate" : "none")
    }
}
