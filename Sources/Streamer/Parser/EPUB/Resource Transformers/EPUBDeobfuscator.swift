//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CryptoSwift
import Foundation
import ReadiumShared

/// Deobfuscates EPUB resources.
/// https://www.w3.org/publishing/epub3/epub-ocf.html#sec-resource-obfuscation
final class EPUBDeobfuscator {
    /// Supported obfuscation algorithms.
    private let algorithms: [ObfuscationAlgorithm] = [IDPFAlgorithm(), AdobeAlgorithm()]

    private let encryptions: [RelativeURL: Encryption]

    /// Publication identifier
    private let publicationId: String

    init(publicationId: String, encryptions: [RelativeURL: Encryption]) {
        self.publicationId = publicationId
            // > All white space characters, as defined in section 2.3 of the XML 1.0 specification
            // > [XML], MUST be removed from this identifier — specifically, the Unicode code points
            // > U+0020, U+0009, U+000D and U+000A.
            // https://www.w3.org/publishing/epub3/epub-ocf.html#obfus-keygen
            .components(separatedBy: .whitespacesAndNewlines).joined()

        self.encryptions = encryptions
    }

    func deobfuscate(resource: Resource, at href: AnyURL) -> Resource {
        // Checks if the resource is obfuscated with a known algorithm.
        guard
            let href = href.relativeURL?.normalized,
            !publicationId.isEmpty, publicationId != "urn:uuid:",
            let algorithmId = encryptions[href]?.algorithm,
            let algorithm = algorithms.first(withIdentifier: algorithmId)
        else {
            return resource
        }

        let key = algorithm.key(for: publicationId)
        return EPUBDeobfuscatingResource(resource: resource, algorithm: algorithm, key: key)
    }

    private final class EPUBDeobfuscatingResource: Resource {
        private let resource: Resource
        private let algorithm: ObfuscationAlgorithm
        private let key: [UInt8]

        init(resource: Resource, algorithm: ObfuscationAlgorithm, key: [UInt8]) {
            assert(key.count > 0)
            self.resource = resource
            self.algorithm = algorithm
            self.key = key
        }

        let sourceURL: AbsoluteURL? = nil

        func estimatedLength() async -> ReadResult<UInt64?> {
            await resource.estimatedLength()
        }

        func properties() async -> ReadResult<ResourceProperties> {
            await resource.properties()
        }

        func stream(range: Range<UInt64>?, consume: @escaping (Data) -> Void) async -> ReadResult<Void> {
            var readPosition = range?.lowerBound ?? 0
            let obfuscatedLength = algorithm.obfuscatedLength

            return await resource.stream(
                range: range,
                consume: { data in
                    var data = data

                    if readPosition < obfuscatedLength {
                        for i in 0 ..< data.count {
                            if readPosition + UInt64(i) >= obfuscatedLength {
                                break
                            }
                            data[i] = data[i] ^ self.key[i % self.key.count]
                        }
                    }

                    readPosition += UInt64(data.count)

                    consume(data)
                }
            )
        }
    }
}

private protocol ObfuscationAlgorithm {
    /// URI identifier for this algorithm.
    var identifier: String { get }

    /// Number of bytes obfuscated at the beggining of the resources.
    var obfuscatedLength: Int { get }

    /// Generates the obfuscation key from the publication identifier.
    func key(for publicationId: String) -> [UInt8]
}

private extension Array where Element == ObfuscationAlgorithm {
    func first(withIdentifier uri: String) -> ObfuscationAlgorithm? {
        first { $0.identifier == uri }
    }
}

private final class IDPFAlgorithm: ObfuscationAlgorithm {
    let identifier = "http://www.idpf.org/2008/embedding"
    let obfuscatedLength = 1040

    func key(for publicationId: String) -> [UInt8] {
        publicationId.sha1().hexaToBytes
    }
}

private final class AdobeAlgorithm: ObfuscationAlgorithm {
    let identifier = "http://ns.adobe.com/pdf/enc#RC"
    let obfuscatedLength = 1024

    func key(for publicationId: String) -> [UInt8] {
        publicationId
            .replacingOccurrences(of: "urn:uuid:", with: "")
            .replacingOccurrences(of: "-", with: "")
            .hexaToBytes
    }
}

private extension String {
    var hexaToBytes: [UInt8] {
        var position = startIndex
        return (0 ..< count / 2).compactMap { _ in
            defer { position = index(position, offsetBy: 2) }

            return UInt8(self[position ... self.index(after: position)], radix: 16)
        }
    }
}
