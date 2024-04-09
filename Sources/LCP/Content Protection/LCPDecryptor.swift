//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

private typealias R2Link = R2Shared.Link

private let lcpScheme = "http://readium.org/2014/01/lcp"
private let AESBlockSize: UInt64 = 16 // bytes

/// Decrypts a resource protected with LCP.
final class LCPDecryptor {
    enum Error: Swift.Error {
        case emptyDecryptedData
        case invalidCBCData
        case invalidRange(Range<UInt64>)
        case inflateFailed
    }

    private let license: LCPLicense?

    init(license: LCPLicense?) {
        self.license = license
    }

    func decrypt(resource: Resource) -> Resource {
        // Checks if the resource is encrypted and whether the encryption schemes of the resource
        // and the DRM license are the same.
        let link = resource.link
        guard let encryption = link.properties.encryption, encryption.scheme == lcpScheme else {
            return resource
        }
        guard let license = license else {
            return FailureResource(link: link, error: .forbidden(nil))
        }

        if link.isDeflated || !link.isCbcEncrypted {
            return FullLCPResource(resource, license: license).cached()

        } else {
            // The ZIP library we currently use doesn't support random access in deflated entries, which causes really
            // bad performances when reading a resource by chunks (e.g. reading a large PDF).
            //
            // A workaround is to cache the resource input stream to reuse it when being requested consecutive ranges.
            // However this isn't enough for LCP, because when requesting a range from an LCP resource, we always read
            // a bit more to align the data with the next AES block. This means that consecutive requests are not
            // properly aligned and the cached input stream is discarded.
            //
            // To fix this issue, we use a `BufferedResource` around the ZIP resource which will keep in memory a few
            // of the previously read bytes. They can then be used to complete the next requested range from the
            // cached input stream's current offset.
            //
            // See https://github.com/readium/r2-shared-swift/issues/98
            // and https://github.com/readium/r2-shared-swift/pull/119
            return CBCLCPResource(resource.buffered(), license: license)
        }
    }

    /// A  LCP resource that is read, decrypted and cached fully before reading requested ranges.
    ///
    /// Can be used when it's impossible to map a read range (byte range request) to the encrypted
    /// resource, for example when the resource is deflated before encryption.
    private class FullLCPResource: TransformingResource {
        private let license: LCPLicense

        init(_ resource: Resource, license: LCPLicense) {
            self.license = license
            super.init(resource)
        }

        override func transform(_ data: ResourceResult<Data>) -> ResourceResult<Data> {
            license.decryptFully(data: data, isDeflated: resource.link.isDeflated)
        }

        override var length: ResourceResult<UInt64> {
            // Uses `originalLength` or falls back on the actual decrypted data length.
            resource.link.properties.encryption?.originalLength.map { .success(UInt64($0)) }
                ?? super.length
        }
    }

    /// A LCP resource used to read content encrypted with the CBC algorithm.
    ///
    /// Supports random access for byte range requests, but the resource MUST NOT be deflated.
    private class CBCLCPResource: ProxyResource {
        private let license: LCPLicense

        init(_ resource: Resource, license: LCPLicense) {
            assert(!resource.link.isDeflated)
            assert(resource.link.isCbcEncrypted)
            self.license = license
            super.init(resource)
        }

        private lazy var plainTextSize: ResourceResult<UInt64> = resource.length.tryFlatMap { length in
            guard length >= 2 * AESBlockSize else {
                throw LCPDecryptor.Error.invalidCBCData
            }

            let readPosition = length - 2 * AESBlockSize
            return resource.read(range: readPosition ..< length)
                .tryMap { encryptedData in
                    guard let data = try license.decipher(encryptedData) else {
                        throw LCPDecryptor.Error.emptyDecryptedData
                    }

                    let paddingSize = UInt64(data.last ?? 0)

                    return length
                        - AESBlockSize // Minus IV or previous block
                        - paddingSize // Minus padding part
                }
        }

        override func read(range: Range<UInt64>?) -> ResourceResult<Data> {
            guard let range = range else {
                return license.decryptFully(data: resource.read(), isDeflated: resource.link.isDeflated)
            }

            return resource.length.tryFlatMap { encryptedLength in
                guard let rangeFirst = range.first, let rangeLast = range.last else {
                    throw LCPDecryptor.Error.invalidRange(range)
                }

                // Encrypted data is shifted by AESBlockSize, because of IV and because the
                // previous block must be provided to perform XOR on intermediate blocks.
                let encryptedStart = rangeFirst.floorMultiple(of: AESBlockSize)
                let encryptedEndExclusive = (rangeLast + 1).ceilMultiple(of: AESBlockSize) + AESBlockSize

                return resource.read(range: encryptedStart ..< encryptedEndExclusive).tryMap { encryptedData in
                    guard let bytes = try license.decipher(encryptedData) else {
                        throw LCPDecryptor.Error.emptyDecryptedData
                    }

                    // Exclude the bytes added to match a multiple of AESBlockSize.
                    let sliceStart = (rangeFirst - encryptedStart)

                    let isLastBlockRead = encryptedLength - encryptedEndExclusive <= AESBlockSize
                    let rangeLength = try isLastBlockRead
                        // Use decrypted length to ensure `rangeLast` doesn't exceed decrypted length - 1.
                        ? min(rangeLast, length.get() - 1) - rangeFirst + 1
                        // The last block won't be read, so there's no need to compute the length
                        : rangeLast - rangeFirst + 1

                    // Keep only enough bytes to fit the length-corrected request in order to never
                    // include padding.
                    let sliceEnd = sliceStart + rangeLength

                    return bytes[sliceStart ..< sliceEnd]
                }
            }
        }

        override var length: ResourceResult<UInt64> { plainTextSize }
    }
}

private extension LCPLicense {
    func decryptFully(data: ResourceResult<Data>, isDeflated: Bool) -> ResourceResult<Data> {
        data.tryMap {
            // Decrypts the resource.
            guard var data = try self.decipher($0) else {
                throw LCPDecryptor.Error.emptyDecryptedData
            }

            // Removes the padding.
            let padding = Int(data[data.count - 1])
            data = data[0 ..< (data.count - padding)]

            // If the ressource was compressed using deflate, inflate it.
            if isDeflated {
                guard let inflatedData = data.inflate() else {
                    throw LCPDecryptor.Error.inflateFailed
                }
                data = inflatedData
            }

            return data
        }
    }
}

private extension R2Link {
    var isDeflated: Bool {
        properties.encryption?.compression?.lowercased() == "deflate"
    }

    var isCbcEncrypted: Bool {
        properties.encryption?.algorithm == "http://www.w3.org/2001/04/xmlenc#aes256-cbc"
    }
}

private extension UInt64 {
    func ceilMultiple(of divisor: UInt64) -> UInt64 {
        divisor * (self / divisor + ((self % divisor == 0) ? 0 : 1))
    }

    func floorMultiple(of divisor: UInt64) -> UInt64 {
        divisor * (self / divisor)
    }
}
