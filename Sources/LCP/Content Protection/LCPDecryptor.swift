//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import ReadiumShared

private let lcpScheme = "http://readium.org/2014/01/lcp"

/// Decrypts a resource protected with LCP.
final class LCPDecryptor {
    enum Error: Swift.Error {
        case emptyDecryptedData
        case invalidCBCData
        case invalidRange(Range<UInt64>)
        case inflateFailed
        case requiredEstimatedLength
        case noPlainTextSize
    }

    private let license: LCPLicense?
    private let encryptionData: [AnyURL: ReadiumShared.Encryption]

    init(license: LCPLicense?, encryptionData: [AnyURL: ReadiumShared.Encryption]) {
        self.license = license
        self.encryptionData = encryptionData.reduce(into: [:]) { result, item in
            result[item.key.normalized] = item.value
        }
    }

    func decrypt(at href: AnyURL, resource: Resource) -> Resource {
        let href = href.normalized

        // Checks if the resource is encrypted and whether the encryption
        // schemes of the resource and the DRM license are the same.
        guard let encryption = encryptionData[href], encryption.scheme == lcpScheme else {
            return resource
        }
        guard let license = license else {
            return FailureResource(error: .decoding("Cannot decipher content because the publication is locked."))
        }

        if encryption.isDeflated || !encryption.isCbcEncrypted {
            return FullLCPResource(resource, license: license, encryption: encryption).cached()

        } else {
            // We use a buffered resource because when requesting a range from
            // an LCP resource, we always read a bit more to align the data with
            // the next AES block. This means that consecutive requests are not
            // properly aligned and might throw off any optimization reusing
            // a single input stream.
            // See https://github.com/readium/r2-shared-swift/issues/98
            // and https://github.com/readium/r2-shared-swift/pull/119
            return CBCLCPResource(resource.buffered(), license: license, encryption: encryption)
        }
    }

    /// An LCP resource that is read, decrypted and cached fully before reading
    /// requested ranges.
    ///
    /// Can be used when it's impossible to map a read range (byte range
    /// request) to the encrypted resource, for example when the resource is
    /// deflated before encryption.
    private final class FullLCPResource: Resource, Sendable {
        private let resource: TransformingResource
        private let originalLength: UInt64?

        init(_ resource: Resource, license: LCPLicense, encryption: ReadiumShared.Encryption) {
            originalLength = encryption.originalLength.map { UInt64($0) }
            self.resource = TransformingResource(resource, transform: { data in
                await license.decryptFully(data: data, isDeflated: encryption.isDeflated)
            })
        }

        let sourceURL: AbsoluteURL? = nil

        func properties() async -> ReadResult<ResourceProperties> {
            await resource.properties()
        }

        func estimatedLength() async -> ReadResult<UInt64?> {
            .success(originalLength)
        }

        func stream(range: Range<UInt64>?, consume: @escaping @Sendable (Data) -> Void) async -> ReadResult<Void> {
            await resource.stream(range: range, consume: consume)
        }
    }

    /// A LCP resource used to read content encrypted with the CBC algorithm.
    ///
    /// Supports random access for byte range requests, but the resource MUST NOT be deflated.
    private final class CBCLCPResource: Resource, Sendable {
        private let resource: Resource
        private let license: LCPLicense
        private let encryption: ReadiumShared.Encryption
        private let plainTextSize: AsyncMemoizer<ReadResult<UInt64?>>

        init(_ resource: Resource, license: LCPLicense, encryption: ReadiumShared.Encryption) {
            assert(!encryption.isDeflated)
            assert(encryption.isCbcEncrypted)
            self.resource = resource
            self.license = license
            self.encryption = encryption

            plainTextSize = AsyncMemoizer { [resource, license] in
                await license.plainTextSizeOfCBCResource(resource)
            }
        }

        let sourceURL: AbsoluteURL? = nil

        func properties() async -> ReadResult<ResourceProperties> {
            .success(ResourceProperties())
        }

        func estimatedLength() async -> ReadResult<UInt64?> {
            await plainTextSize()
        }

        func stream(range: Range<UInt64>?, consume: @escaping @Sendable (Data) -> Void) async -> ReadResult<Void> {
            guard let range = range else {
                return await license.decryptFully(data: resource.read(), isDeflated: encryption.isDeflated)
                    .map {
                        consume($0)
                        return ()
                    }
            }

            return await resource.estimatedLength().asyncFlatMap { encryptedLength in
                guard let encryptedLength = encryptedLength else {
                    return .failure(.decoding(LCPDecryptor.Error.requiredEstimatedLength))
                }
                guard let rangeFirst = range.first, let rangeLast = range.last else {
                    return .failure(.decoding(LCPDecryptor.Error.invalidRange(range)))
                }

                // Encrypted data is shifted by AESBlockSize, because of IV and because the
                // previous block must be provided to perform XOR on intermediate blocks.
                let encryptedStart = rangeFirst.floorMultiple(of: AESBlockSize)
                let encryptedEndExclusive = min(
                    (rangeLast + 1).ceilMultiple(of: AESBlockSize) + AESBlockSize,
                    encryptedLength
                )

                return await resource.read(range: encryptedStart ..< encryptedEndExclusive)
                    .combine(plainTextSize())
                    .flatMap { encryptedData, plainTextSize in
                        do {
                            guard let plainTextSize = plainTextSize else {
                                return .failure(.decoding(LCPDecryptor.Error.noPlainTextSize))
                            }
                            guard let bytes = try license.decipher(encryptedData) else {
                                return .failure(.decoding(LCPDecryptor.Error.emptyDecryptedData))
                            }

                            // Exclude the bytes added to match a multiple of AESBlockSize.
                            let sliceStart = (rangeFirst - encryptedStart)

                            let isLastBlockRead = encryptedLength - encryptedEndExclusive <= AESBlockSize
                            let rangeLength = isLastBlockRead
                                // Use decrypted length to ensure `rangeLast` doesn't exceed decrypted length - 1.
                                ? min(rangeLast, plainTextSize - 1) - rangeFirst + 1
                                // The last block won't be read, so there's no need to compute the length
                                : rangeLast - rangeFirst + 1

                            // Keep only enough bytes to fit the length-corrected request in order to never
                            // include padding.
                            let sliceEnd = sliceStart + rangeLength

                            consume(bytes[sliceStart ..< sliceEnd])
                            return .success(())
                        } catch {
                            return .failure(.decoding(error))
                        }
                    }
            }
        }
    }
}

private extension LCPLicense {
    /// Computes the plain text size of a CBC-encrypted, non-deflated LCP
    /// resource.
    ///
    /// The size of an LCP-encrypted resource doesn't match the size of its
    /// decrypted content, because of:
    ///   - the 16-byte IV prepended to the ciphertext, and
    ///   - the PKCS#7 padding (1...16 bytes) appended to align the plaintext
    ///     on a multiple of `AESBlockSize`.
    ///
    /// To recover the exact plain text size without decrypting the whole
    /// resource, we read and decrypt only the last two AES blocks: the second-
    /// to-last block serves as the IV for the last one, whose final byte
    /// encodes the padding length per PKCS#7.
    ///
    /// - Important: This must only be called on a CBC-encrypted resource that
    ///   is **not** deflated. On a deflated resource, the returned value would
    ///   be the *compressed* size, not the actual plain text size.
    ///
    /// - Returns: The decrypted content length in bytes, or a failure if
    ///   the resource is not a valid CBC chunk or cannot be deciphered.
    func plainTextSizeOfCBCResource(_ resource: Resource) async -> ReadResult<UInt64?> {
        await resource.estimatedLength().asyncFlatMap { length in
            guard let length = length else {
                return .failure(.decoding(LCPDecryptor.Error.requiredEstimatedLength))
            }
            guard length.isValidAESChunk else {
                return .failure(.decoding(LCPDecryptor.Error.invalidCBCData))
            }

            // Read the last two AES blocks: the penultimate one is needed as
            // the IV to decrypt the last one, which carries the PKCS#7 padding.
            let readPosition = length - 2 * AESBlockSize
            return await resource.read(range: readPosition ..< length)
                .flatMap { encryptedData in
                    do {
                        guard let data = try self.decipher(encryptedData) else {
                            return .failure(.decoding(LCPDecryptor.Error.emptyDecryptedData))
                        }

                        let paddingSize = UInt64(data.last ?? 0)
                        return .success(
                            length
                                - AESBlockSize // IV
                                - paddingSize // PKCS#7 padding
                        )
                    } catch {
                        return .failure(.decoding(error))
                    }
                }
        }
    }

    func decryptFully(data: ReadResult<Data>, isDeflated: Bool) async -> ReadResult<Data> {
        data.flatMap {
            guard UInt64($0.count).isValidAESChunk else {
                return .failure(.decoding(LCPDecryptor.Error.invalidCBCData))
            }

            do {
                // Decrypts the resource.
                guard var data = try self.decipher($0) else {
                    return .failure(.decoding(LCPDecryptor.Error.emptyDecryptedData))
                }

                // Removes the padding.
                let padding = Int(data[data.count - 1])
                data = data[0 ..< (data.count - padding)]

                // If the ressource was compressed using deflate, inflate it.
                if isDeflated {
                    guard let inflatedData = data.inflate() else {
                        return .failure(.decoding(LCPDecryptor.Error.inflateFailed))
                    }
                    data = inflatedData
                }

                return .success(data)
            } catch {
                return .failure(.decoding(error))
            }
        }
    }
}

private extension ReadiumShared.Encryption {
    var isDeflated: Bool {
        compression?.lowercased() == "deflate"
    }

    var isCbcEncrypted: Bool {
        algorithm == "http://www.w3.org/2001/04/xmlenc#aes256-cbc"
    }
}

private let AESBlockSize: UInt64 = 16 // bytes

private extension UInt64 {
    /// Checks if this number is a valid CBC length - i.e. a multiple of AES
    /// block size and at least 2 blocks (IV + data).
    /// If not, the file is likely not actually encrypted despite being declared
    /// as such.
    var isValidAESChunk: Bool {
        self >= 2 * AESBlockSize && self % AESBlockSize == 0
    }
}
