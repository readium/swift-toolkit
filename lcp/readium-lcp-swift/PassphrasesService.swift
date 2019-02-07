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
import R2LCPClient
import CryptoSwift


public enum PassphraseRequestReason {
    /// No matching passphrase was found.
    case notFound
    /// The provided passphrase was invalid.
    case invalid
}


protocol PassphrasesServiceDelegate: AnyObject {
    
    /// Called when the service can't find any valid passphrase in the repository, as a fallback.
    /// Can be used, for example, to prompt the user for the passphrase.
    func requestPassphrase(for license: LicenseDocument, reason: PassphraseRequestReason, completion: @escaping (String?) -> Void)
    
}


final class PassphrasesService {

    public weak var delegate: PassphrasesServiceDelegate?
    
    private let repository: PassphrasesRepository

    init(repository: PassphrasesRepository) {
        self.repository = repository
    }
    
    /// Finds any valid passphrase for the given license in the passphrases repository.
    /// If none is found, requests a passphrase from the request delegate (ie. user prompt) until one is valid, or the request is cancelled.
    func request(for license: LicenseDocument, completion: @escaping (Result<String>) -> Void) {
        let candidates = possiblePassphrasesFromRepository(for: license)
        if let passphrase = findOneValidPassphrase(jsonLicense: license.json, hashedPassphrases: candidates) {
            completion(.success(passphrase))
        } else {
            requestFromDelegate(for: license, reason: .notFound, completion: completion)
        }
    }
    
    /// Called when the service can't find any valid passphrase in the repository, as a fallback.
    private func requestFromDelegate(for license: LicenseDocument, reason: PassphraseRequestReason, completion: @escaping (Result<String>) -> Void) {
        guard let delegate = self.delegate else {
            completion(.failure(LcpError.cancelled))
            return
        }
        
        delegate.requestPassphrase(for: license, reason: reason) { [weak self] clearPassphrase in
            guard let `self` = self, let clearPassphrase = clearPassphrase else {
                completion(.failure(LcpError.cancelled))
                return
            }
            
            let hashedPassphrase = clearPassphrase.sha256()
            guard let passphrase = findOneValidPassphrase(jsonLicense: license.json, hashedPassphrases: [hashedPassphrase]) else {
                // Tries again if the passphrase is invalid, until cancelled
                self.requestFromDelegate(for: license, reason: .invalid, completion: completion)
                return
            }
            
            // Saves the passphrase to open the publication right away next time
            self.repository.addPassphrase(passphrase, forLicenseId: license.id, provider: license.provider.absoluteString, userId: license.user.id)
            
            completion(.success(passphrase))
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
