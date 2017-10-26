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

// Implementation of the Decipherer protocol for LCP.
// This is used in the DRM object to be able to decipher data.
public class DeciphererLcp: Decipherer {
    
    internal var context: DRMContext?
    
    internal init() {}
    
    public func decipher(_ data: Data) throws -> Data? {
        guard let context = context else {
            throw LcpError.invalidContext
        }
        return LCPClient.decrypt(data: data, using: context)
    }
}

public class LcpSession {
    internal let lcp: Lcp
    
    public init(protectedEpubUrl url: URL) throws {
        lcp = try Lcp.init(withLicenseDocumentIn: url)
    }
    
    /// Generate a Decipherer for the LCP drm.
    ///
    /// - Parameters:
    ///   - passphrase: The passphrase.
    ///   - completion: The code to be exected on success.
    public func resolve(using passphrase: String, pemCrl: String) -> Promise<DeciphererLcp>
    {
        return firstly {
            // 4/ Check the license status
            lcp.fetchStatusDocument()
            }.then { _ -> Promise<Void> in
                /// 3.3/ Check that the status is "ready" or "active".
                guard self.lcp.status?.status == StatusDocument.Status.ready
                    || self.lcp.status?.status == StatusDocument.Status.active else {
                        /// If this is not the case (revoked, returned, cancelled,
                        /// expired), the app will notify the user and stop there.
                        throw LcpError.licenseStatus
                }
                /// 3.4/ Check if the license has been updated. If it is the case,
                //       the app must:
                /// 3.4.1/ Fetch the updated license.
                /// 3.4.2/ Validate the updated license. If the updated license
                ///        is not valid, the app must keep the current one.
                /// 3.4.3/ Replace the current license by the updated one in the
                ///        EPUB archive.
                return self.lcp.updateLicenseDocument()
            }.then { _ -> Promise<DeciphererLcp> in
                /// 4/ Check the rights.
                guard self.lcp.areRightsValid() else {
                    throw LcpError.invalidRights
                }
                /// 5/ Register the device / license if needed.
                self.lcp.register()
                
                return self.initializeDeciphererLcp(jsonLicense: self.lcp.license.json, passphrase: passphrase, pemCrl: pemCrl)
            }.catch { error in
                print("Error: \(error.localizedDescription)")
        }
    }
    
    func initializeDeciphererLcp(jsonLicense: String, passphrase: String, pemCrl: String) -> Promise<DeciphererLcp> {
        return Promise<DeciphererLcp> { fulfill, reject in
            LCPClient.createContext(jsonLicense: jsonLicense, hashedPassphrase: passphrase, pemCrl: pemCrl) { (error, context) in
                if let error = error {
                    reject(error)
                    return
                }
                let deciphererLcp = DeciphererLcp()
                
                deciphererLcp.context = context
                fulfill(deciphererLcp)
            }
        }
    }
    
    public func getHint() -> String {
        return lcp.license.getHint()
    }
    
    public func getProfile() -> String {
        return lcp.license.encryption.profile.absoluteString
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
                    reject(LcpError.noPassphraseFound)
                    return
                }
                fulfill(passphrase)
            }
            
            LCPClient.findOneValidPassphrase(jsonLicense: lcp.license.json,
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
        passphrases = (try? db.transactions.possiblePassphrases(for: lcp.license.id,
                                                                and: lcp.license.provider)) ?? []
        
        guard !passphrases.isEmpty else {
            return Promise(value: nil)
        }
        return checkPassphrases(passphrases)
    }
    
    
    public func storePassphrase(_ passphraseHash: String) throws
    {
        let db = LCPDatabase.shared
        let licenseId = lcp.license.id
        let provider = lcp.license.provider.absoluteString
        
        try db.transactions.add(licenseId, provider, passphraseHash)
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










