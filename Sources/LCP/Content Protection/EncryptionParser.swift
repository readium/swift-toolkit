//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

func parseEncryptionData(in asset: ContainerAsset) async -> ReadResult<[AnyURL: ReadiumShared.Encryption]> {
    if asset.format.conformsTo(.epub) {
        return await parseEPUBEncryptionData(in: asset.container)
    } else {
        return await parseRPFEncryptionData(in: asset.container)
    }
}

private func parseRPFEncryptionData(in container: Container) async -> ReadResult<[AnyURL: ReadiumShared.Encryption]> {
    guard let manifestResource = container[RelativeURL(path: "manifest.json")!] else {
        return .failure(.decoding("Missing RWPM manifest"))
    }

    return await manifestResource
        .readAsJSONObject()
        .flatMap { json in
            do {
                return try .success(Manifest(json: json))
            } catch {
                return .failure(.decoding(error))
            }
        }
        .map { manifest in
            (manifest.readingOrder + manifest.resources)
                .reduce([:]) { data, link in
                    var data = data
                    if let encryption = link.properties.encryption {
                        data[link.url()] = encryption
                    }
                    return data
                }
        }
}

private func parseEPUBEncryptionData(in container: Container) async -> ReadResult<[AnyURL: ReadiumShared.Encryption]> {
    guard let encryptionResource = container[RelativeURL(path: "META-INF/encryption.xml")!] else {
        return .failure(.decoding("Missing META-INF/encryption.xml"))
    }

    return await encryptionResource.read()
        .asyncFlatMap { data -> ReadResult<XMLDocument> in
            do {
                let doc = try await DefaultXMLDocumentFactory().open(
                    data: data,
                    namespaces: [.enc, .ds, .comp]
                )
                return .success(doc)
            } catch {
                return .failure(.decoding(error))
            }
        }
        .flatMap { document in
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

            return .success(encryptions)
        }
}
