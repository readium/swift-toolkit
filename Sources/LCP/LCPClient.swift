//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Protocol to implement in reading apps to create a facade to the private R2LCPClient.framework (liblcp).
///
/// You can copy and paste this implementation in your project:
///
///     import R2LCPClient
///     import ReadiumLCP
///
///     /// Facade to the private R2LCPClient.framework.
///     class LCPClient: ReadiumLCP.LCPClient {
///
///         func createContext(jsonLicense: String, hashedPassphrase: String, pemCrl: String) throws -> LCPClientContext {
///              return try R2LCPClient.createContext(jsonLicense: jsonLicense, hashedPassphrase: hashedPassphrase, pemCrl: pemCrl)
///          }
///
///          func decrypt(data: Data, using context: LCPClientContext) -> Data? {
///              return R2LCPClient.decrypt(data: data, using: context as! DRMContext)
///          }
///
///          func findOneValidPassphrase(jsonLicense: String, hashedPassphrases: [String]) -> String? {
///              return R2LCPClient.findOneValidPassphrase(jsonLicense: jsonLicense, hashedPassphrases: hashedPassphrases)
///          }
///
///      }
public protocol LCPClient {
    /// Create a context for a given license/passphrase tuple.
    func createContext(jsonLicense: String, hashedPassphrase: LCPPassphraseHash, pemCrl: String) throws -> LCPClientContext

    /// Decrypt provided content, given a valid context is provided.
    func decrypt(data: Data, using context: LCPClientContext) -> Data?

    /// Given an array of possible password hashes, return a valid password hash for the lcpl licence.
    func findOneValidPassphrase(jsonLicense: String, hashedPassphrases: [LCPPassphraseHash]) -> LCPPassphraseHash?
}

public typealias LCPClientContext = Any

/// Copy of the R2LCPClient.LCPClientError enum.
///
/// Order is important, because it is used to match the original enum cases.
public enum LCPClientError: Int, Error {
    case licenseOutOfDate = 0
    case certificateRevoked
    case certificateSignatureInvalid
    case licenseSignatureDateInvalid
    case licenseSignatureInvalid
    case contextInvalid
    case contentKeyDecryptError
    case userKeyCheckInvalid
    case contentDecryptError
    case unknown
}
