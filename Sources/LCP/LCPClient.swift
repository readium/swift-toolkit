//
//  Copyright 2026 Readium Foundation. All rights reserved.
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
///          func getSupportedLCPProfileURIs() -> [String] {
///              return R2LCPClient.getSupportedLCPProfileURIs() ?? []
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

    /// Returns the LCP profile URIs supported by the underlying liblcp build.
    func getSupportedLCPProfileURIs() -> [String]
}

public extension LCPClient {
    // FIXME: This default implementation preserves source compatibility for facades that predate `getSupportedLCPProfileURIs()`. Remove it in the next breaking release and make the method a hard protocol requirement, so the supported profiles always come from liblcp instead of this stale hardcoded list.
    func getSupportedLCPProfileURIs() -> [String] {
        [
            "http://readium.org/lcp/basic-profile",
            "http://readium.org/lcp/profile-1.0",
            "http://readium.org/lcp/profile-2.0",
            "http://readium.org/lcp/profile-2.1",
            "http://readium.org/lcp/profile-2.2",
            "http://readium.org/lcp/profile-2.3",
            "http://readium.org/lcp/profile-2.4",
            "http://readium.org/lcp/profile-2.5",
            "http://readium.org/lcp/profile-2.6",
            "http://readium.org/lcp/profile-2.7",
            "http://readium.org/lcp/profile-2.8",
            "http://readium.org/lcp/profile-2.9",
        ]
    }
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
