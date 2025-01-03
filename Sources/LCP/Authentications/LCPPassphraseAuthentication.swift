//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// An `LCPAuthenticating` implementation which can directly use a provided clear or hashed
/// passphrase.
///
/// If the provided `passphrase` is incorrect, the given `fallback` authentication is used.
public class LCPPassphraseAuthentication: LCPAuthenticating {
    private let passphrase: String
    private let fallback: LCPAuthenticating?

    public init(_ passphrase: String, fallback: LCPAuthenticating? = nil) {
        self.passphrase = passphrase
        self.fallback = fallback
    }

    public func retrievePassphrase(for license: LCPAuthenticatedLicense, reason: LCPAuthenticationReason, allowUserInteraction: Bool, sender: Any?) async -> String? {
        guard reason == .passphraseNotFound else {
            if let fallback = fallback {
                return await fallback.retrievePassphrase(for: license, reason: reason, allowUserInteraction: allowUserInteraction, sender: sender)
            } else {
                return nil
            }
        }

        return passphrase
    }
}
