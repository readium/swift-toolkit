//
//  LcpUtils.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/14/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import PromiseKit
import ZIPFoundation
import R2Shared
import R2LCPClient
import CryptoSwift

public class LcpSession {
    internal let lcpLicense: LcpLicense
    
    public init(protectedEpubUrl url: URL) throws {
        lcpLicense = try LcpLicense.init(withLicenseDocumentIn: url)
    }
    
    /// Generate a Decipherer for the LCP drm.
    ///
    /// - Parameters:
    ///   - passphrase: The passphrase.
    ///   - completion: The code to be exected on success.
    public func resolve(using passphrase: String, pemCrl: String) -> Promise<LcpLicense> {
        return firstly {
            // 4/ Check the license status
            lcpLicense.fetchStatusDocument()
            }.then { _ -> Promise<Void> in
                /// 3.3/ Check that the status is "ready" or "active".
                try self.lcpLicense.checkStatus()
                /// 3.4/ Check if the license has been updated. If it is the case,
                //       the app must:
                /// 3.4.1/ Fetch the updated license.
                /// 3.4.2/ Validate the updated license. If the updated license
                ///        is not valid, the app must keep the current one.
                /// 3.4.3/ Replace the current license by the updated one in the
                ///        EPUB archive.
                return self.lcpLicense.updateLicenseDocument()
            }.then { _ -> Promise<LcpLicense> in
                /// 4/ Check the rights.
                try self.lcpLicense.areRightsValid()
                /// 5/ Register the device / license if needed.
                self.lcpLicense.register()

                return self.getLcpContext(jsonLicense: self.lcpLicense.license.json,
                                          passphrase: passphrase,
                                          pemCrl: pemCrl)
            }
    }

    /// <#Description#>
    ///
    /// - Parameters:
    ///   - jsonLicense: <#jsonLicense description#>
    ///   - passphrase: <#passphrase description#>
    ///   - pemCrl: <#pemCrl description#>
    /// - Returns: <#return value description#>
    func getLcpContext(jsonLicense: String, passphrase: String, pemCrl: String) -> Promise<LcpLicense> {
        return Promise<LcpLicense> { fulfill, reject in
            createContext(jsonLicense: jsonLicense, hashedPassphrase: passphrase, pemCrl: pemCrl) { (error, context) in
                if let error = error {
                    reject(error)
                    return
                }
                
                self.lcpLicense.context = context
                fulfill(self.lcpLicense)
            }
        }
    }
    
    public func getHint() -> String {
        return lcpLicense.license.getHint()
    }
    
    public func getProfile() -> String {
        return lcpLicense.license.encryption.profile.absoluteString
    }
    
    /// Call R2LCPClient to check if any of the provided passphrases are valid,
    /// for the given license.
    ///
    /// - Parameter passphrases: Passphrases hashes to test for validity.
    /// - Returns: A validated passphrase hash if found, else nil.
    public func checkPassphrases(_ passphrases: [String]) -> Promise<String?> {
        return Promise<String?> { fulfill, reject in
            
            func completionHandler(error: Error?, passphrase: String?) {
                if let error = error as Error? {
                    reject(error)
                    return
                }
                guard let passphrase = passphrase else {
                    reject(LcpError.invalidPassphrase)
                    return
                }
                fulfill(passphrase)
            }
            
            findOneValidPassphrase(jsonLicense: lcpLicense.license.json,
                                             hashedPassphrases: passphrases,
                                             completionHandler: completionHandler)
        }
    }
    
    /// <#Description#>
    ///
    /// - Returns: <#return value description#>
    /// - Throws: <#throws value description#>
    public func passphraseFromDb() throws -> Promise<String?> {
        /// 2.1/ Check if a passphrase hash has already been stored for the license.
        /// 2.2/ Check if one or more passphrase hash associated with licenses
        ///      from the same provider have been stored.
        var passphrases = [String]()
        let db = LCPDatabase.shared
        passphrases = (try? db.transactions.possiblePassphrases(for: lcpLicense.license.id,
                                                                and: lcpLicense.license.user.id)) ?? []
        
        guard !passphrases.isEmpty else {
            return Promise(value: nil)
        }
        return checkPassphrases(passphrases)
    }
    
    
    public func storePassphrase(_ passphraseHash: String) throws
    {
        let db = LCPDatabase.shared
        let licenseId = lcpLicense.license.id
        let provider = lcpLicense.license.provider.absoluteString
        let userId = lcpLicense.license.user.id
        
        try db.transactions.add(licenseId, provider, userId, passphraseHash)
    }
    
    /// <#Description#>
    ///
    /// - Returns: <#return value description#>
    /// - Throws: <#throws value description#>
    public func validateLicense() throws -> Promise<Void> {
        // JSON Schema or something // TODO
        return Promise<Void>()
    }
}










