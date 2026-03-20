//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

func parseEncryptionData(in asset: ContainerAsset) async throws(ReadError) -> [AnyURL: ReadiumShared.Encryption] {
    if asset.format.conformsTo(.epub) {
        return try await parseEPUBEncryptionData(in: asset.container)
    } else {
        return try await parseRPFEncryptionData(in: asset.container)
    }
}

private func parseRPFEncryptionData(in container: Container) async throws(ReadError) -> [AnyURL: ReadiumShared.Encryption] {
    guard let manifestResource = container[RelativeURL(path: "manifest.json")!] else {
        throw .decoding("Missing RWPM manifest")
    }

    let json = try await manifestResource.read().asJSONObjectValue()

    let manifest: Manifest
    do {
        guard let parsed = try Manifest(json: json) else {
            throw ReadError.decoding("Manifest JSON is invalid or could not be parsed")
        }
        manifest = parsed
    } catch let error as ReadError {
        throw error
    } catch {
        throw .decoding(error)
    }

    return (manifest.readingOrder + manifest.resources)
        .reduce([:]) { data, link in
            var data = data
            if let encryption = link.properties.encryption {
                data[link.url()] = encryption
            }
            return data
        }
}

private func parseEPUBEncryptionData(in container: Container) async throws(ReadError) -> [AnyURL: ReadiumShared.Encryption] {
    guard let encryptionResource = container[RelativeURL(path: "META-INF/encryption.xml")!] else {
        throw .decoding("Missing META-INF/encryption.xml")
    }

    let data = try await encryptionResource.read()

    let document: XMLDocument
    do {
        document = try DefaultXMLDocumentFactory().open(
            data: data,
            namespaces: [.enc, .ds, .comp]
        )
    } catch {
        throw .decoding(error)
    }

    var encryptions: [AnyURL: ReadiumShared.Encryption] = [:]

    // Loop through <EncryptedData> elements..
    for encryptedDataElement in document.all("./enc:EncryptedData") {
        guard
            let algorithm = encryptedDataElement.first("enc:EncryptionMethod")?
            .attribute(named: "Algorithm"),
            let resourceURI = encryptedDataElement.first("enc:CipherData/enc:CipherReference")?
            .attribute(named: "URI")
            .flatMap({ RelativeURL(epubHREF: $0)?.anyURL })
        else {
            continue
        }

        var scheme: String?
        var originalLength: Int?
        var compression: String?

        let keyInfoURI = encryptedDataElement.first("ds:KeyInfo/ds:RetrievalMethod")?.attribute(named: "URI")
        if keyInfoURI == "license.lcpl#/encryption/content_key" {
            scheme = "http://readium.org/2014/01/lcp"
        }

        for encryptionProperty in encryptedDataElement.all("enc:EncryptionProperties/enc:EncryptionProperty") {
            // Check that we have a compression element, with originalLength, not empty.
            if let compressionElement = encryptionProperty.first("comp:Compression"),
               let method = compressionElement.attribute(named: "Method"),
               let length = compressionElement.attribute(named: "OriginalLength")
            {
                originalLength = Int(length)
                compression = (method == "8" ? "deflate" : "none")
                break
            }
        }

        encryptions[resourceURI] = ReadiumShared.Encryption(
            algorithm: algorithm,
            compression: compression,
            originalLength: originalLength,
            scheme: scheme
        )
    }

    return encryptions
}
