//
//  PassphrasesService.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 04.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import CryptoSwift
import R2LCPClient
import R2Shared


final class PassphrasesService {

    private let repository: PassphrasesRepository
    
    private let sha256Predicate = NSPredicate(format: "SELF MATCHES[c] %@", "^([a-f0-9]{64})$")

    init(repository: PassphrasesRepository) {
        self.repository = repository
    }
    
    /// Finds any valid passphrase for the given license in the passphrases repository.
    /// If none is found, requests a passphrase from the request delegate (ie. user prompt) until one is valid, or the request is cancelled.
    /// The returned passphrase is nil if the request was cancelled by the user.
    func request(for license: LicenseDocument, authentication: LCPAuthenticating?) -> Deferred<String?> {
        return Deferred {
            let candidates = self.possiblePassphrasesFromRepository(for: license)
            if let passphrase = findOneValidPassphrase(jsonLicense: license.json, hashedPassphrases: candidates) {
                return .success(passphrase)
            } else if let authentication = authentication {
                return self.authenticate(for: license, reason: .passphraseNotFound, using: authentication)
            } else {
                return .success(nil)
            }
        }
    }
    
    /// Called when the service can't find any valid passphrase in the repository, as a fallback.
    private func authenticate(for license: LicenseDocument, reason: LCPAuthenticationReason, using authentication: LCPAuthenticating) -> Deferred<String?> {
        return Deferred<String?> { success, _ in
                let authenticatedLicense = LCPAuthenticatedLicense(document: license)
                authentication.requestPassphrase(for: authenticatedLicense, reason: reason, completion: success)
            }
            .flatMap { clearPassphrase in
                guard let clearPassphrase = clearPassphrase else {
                    return .success(nil)
                }
    
                let hashedPassphrase = clearPassphrase.sha256()
                var passphrases = [hashedPassphrase]
                // Note: The C++ LCP lib crashes if we provide a passphrase that is not a valid
                // SHA-256 hash. So we check this beforehand.
                if self.sha256Predicate.evaluate(with: clearPassphrase) {
                    passphrases.append(clearPassphrase)
                }
                
                guard let passphrase = findOneValidPassphrase(jsonLicense: license.json, hashedPassphrases: passphrases) else {
                    // Tries again if the passphrase is invalid, until cancelled
                    return self.authenticate(for: license, reason: .invalidPassphrase, using: authentication)
                }

                // Saves the passphrase to open the publication right away next time
                self.repository.addPassphrase(passphrase, forLicenseId: license.id, provider: license.provider, userId: license.user.id)
                
                return .success(passphrase)
            }
    }
    
    /// Finds any potential passphrase candidates (eg. similar user ID) for the given license, from the passphrases repository.
    private func possiblePassphrasesFromRepository(for license: LicenseDocument) -> [String] {
        var passphrases: [String] = []

        if let licensePassphrase = repository.passphrase(forLicenseId: license.id) {
            passphrases.append(licensePassphrase)
        }

        if let userId = license.user.id {
            let userPassphrases = repository.passphrases(forUserId: userId)
            passphrases.append(contentsOf: userPassphrases)
        }

        return passphrases
    }

}
