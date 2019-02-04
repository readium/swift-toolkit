//
//  LcpUtils.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/14/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import PromiseKit
import ZIPFoundation
import R2Shared
import R2LCPClient
import CryptoSwift

let kShouldPresentLcpMessage = "kShouldPresentLcpMessage"

protocol LcpSessionDelegate: AnyObject {
    
    /// Request a passphrase for the given License Document.
    /// Most likely, a prompt will be presented to the user, but the app might fetch the passphrase another way.
    func requestPassphrase(for license: LicenseDocument, reason: LcpPassphraseRequestReason) -> Promise<LcpPassphraseRequest>
    
}

internal class LcpSession {
    internal let lcpLicense: LcpLicense
    internal let delegate: LcpSessionDelegate
    
    init(licenseDocument url: URL, delegate: LcpSessionDelegate) throws {
        self.lcpLicense = try LcpLicense.init(withLicenseDocumentAt: url)
        self.delegate = delegate
    }
    
    init(protectedEpubUrl url: URL, delegate: LcpSessionDelegate) throws {
        self.lcpLicense = try LcpLicense.init(withLicenseDocumentIn: url)
        self.delegate = delegate
    }

    /// Process a LCP License Document (LCPL).
    /// Fetching Status Document, updating License Document, Fetching Publication,
    /// and moving the (updated) License Document into the publication archive.
    ///
    /// - Parameters:
    ///   - path: The path of the License Document (LCPL).
    ///   - completion: The handler to be called on completion.
    func downloadPublication() -> Promise<(URL, URLSessionDownloadTask?)> {
        return evaluate()
            .then { _ -> Promise<(URL, URLSessionDownloadTask?)> in
                return self.lcpLicense.fetchPublication()
            }
            .then { (publicationUrl, downloadTask) -> Promise<(URL, URLSessionDownloadTask?)> in
                /// Move the license document in the publication.
                try LcpLicense.moveLicense(from: self.lcpLicense.archivePath, to: publicationUrl)
                return Promise(value: (publicationUrl, downloadTask))
            }
    }
    
    /// Generate a Decipherer for the LCP drm.
    ///
    /// - Parameters:
    ///   - passphrase: The passphrase.
    ///   - completion: The code to be executed on success.
    func resolve(using passphrase: String, pemCrl: String) -> Promise<LcpLicense> {
        return evaluate()
            .then { _ -> Promise<LcpLicense> in
                return self.getLcpContext(jsonLicense: self.lcpLicense.license.json,
                                          passphrase: passphrase,
                                          pemCrl: pemCrl)
            }
    }
    
    internal func evaluate() -> Promise<Void> {
        return firstly {
                // 4/ Check the license status
                self.lcpLicense.fetchStatusDocument(shouldRejectError: false)
            }.then{ error -> Promise<Void> in
                
                guard let serverError = error as NSError? else {
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
                }
                
                if serverError.domain == "org.readium" {
                    let noteName = Notification.Name(kShouldPresentLcpMessage)
                    let userInfo = serverError.userInfo
                    
                    let notification = Notification(name: noteName, object: nil, userInfo: userInfo)
                    NotificationCenter.default.post(notification)
                }
                
                return self.lcpLicense.saveLicenseDocumentWithoutStatus(shouldRejectError: false)
                
            }.then {
                /// 4/ Check the rights.
                try self.lcpLicense.areRightsValid()
                /// 5/ Register the device / license if needed.
                self.lcpLicense.register()
                
                return Promise<Void>()
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
    
    /// Call R2LCPClient to check if any of the provided passphrases are valid,
    /// for the given license.
    ///
    /// - Parameter passphrases: Passphrases hashes to test for validity.
    /// - Returns: A validated passphrase hash if found, else nil.
    func checkPassphrases(_ passphrases: [String]) -> Promise<String?> {
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
    func passphraseFromDb() throws -> Promise<String?> {
        /// 2.1/ Check if a passphrase hash has already been stored for the license.
        /// 2.2/ Check if one or more passphrase hash associated with licenses
        ///      from the same provider have been stored.
        var passphrases = [String]()
        let db = LcpDatabase.shared
        passphrases = (try? db.transactions.possiblePassphrases(for: lcpLicense.license.id,
                                                                and: lcpLicense.license.user.id)) ?? []
        
        guard !passphrases.isEmpty else {
            return Promise(value: nil)
        }
        return checkPassphrases(passphrases)
    }
    
    /// Store a passphrase hash to the database
    ///
    /// - Parameter passphraseHash: the hash to store
    func storePassphrase(_ passphraseHash: String) throws
    {
        let db = LcpDatabase.shared
        let licenseId = lcpLicense.license.id
        let provider = lcpLicense.license.provider.absoluteString
        let userId = lcpLicense.license.user.id
        
        try db.transactions.add(licenseId, provider, userId, passphraseHash)
    }
    
    /// <#Description#>
    ///
    /// - Returns: <#return value description#>
    /// - Throws: <#throws value description#>
    func validateLicense() throws -> Promise<Void> {
        // JSON Schema or something // TODO
        return Promise<Void>()
    }
    
    func loadDrm(_ completion: @escaping (LcpLicense?, LcpError?) -> Void) throws
    {
        let kCRLDate = "kCRLDate"
        let kCRLString = "kCRLString"
        
        let updateCRL = { (newCRL:String) -> Void in
            UserDefaults.standard.set(newCRL, forKey: kCRLString)
            UserDefaults.standard.set(Date(), forKey: kCRLDate)
        }
        
        func validatePassphrase(passphraseHash: String) -> Promise<LcpLicense> {
            return firstly {
                let promiseCRL =  { () -> Promise<String> in
                    return Promise<String> { fulfill, reject in
                        let fallback:(()->Void) = { () -> Void in
                            let stringCRL = UserDefaults.standard.value(forKey: "kCRLString") as? String
                            //let dateCRL = UserDefaults.standard.value(forKey: "kCRLStringUpdatedDate") as? Date
                            fulfill(stringCRL ?? "")
                        }
                        self.fetchCRL(success: { (pem:String) in
                            updateCRL(pem)
                            fulfill(pem)
                        }, fail: {
                            fallback()
                        })
                    }
                }
                
                guard let updatedDate = UserDefaults.standard.value(forKey: kCRLDate) as? Date else {
                    return promiseCRL()
                }
                
                let calendar = NSCalendar.current
                
                let updatedCal = calendar.startOfDay(for: updatedDate)
                let currentCal = calendar.startOfDay(for: Date())
                
                let components = calendar.dateComponents([.day], from: updatedCal, to: currentCal)
                let dayCount = components.day ?? Int.max
                if dayCount < 7 {
                    guard let stringCRL = UserDefaults.standard.value(forKey: kCRLString) as? String else {
                        return promiseCRL()
                    }
                    return Promise<String> { fulfill, reject in
                        fulfill(stringCRL)
                    }
                } else {
                    return promiseCRL()
                }
                
            }.then { pemCrl -> Promise<LcpLicense> in
                // Get a decipherer object for the given passphrase,
                // also checking that it's not revoqued using the crl.
                return self.resolve(using: passphraseHash, pemCrl: pemCrl)
            }
        }
        
        // Fonction used in the async code below.
        func promptPassphrase(reason: LcpPassphraseRequestReason = .unknownPassphrase) -> Promise<String> {
            return firstly {
                self.delegate.requestPassphrase(for: self.lcpLicense.license, reason: reason)
                
            }.then { request -> Promise<String?> in
                switch request {
                case .cancelled:
                    throw LcpError.cancelled
                    
                case .passphrase(let clearPassphrase):
                    let passphraseHash = clearPassphrase.sha256()
                    return self.checkPassphrases([passphraseHash])
                }

            }.then { validPassphraseHash -> Promise<String> in
                guard let validPassphraseHash = validPassphraseHash else {
                    throw LcpError.unknown(nil)
                }
                try self.storePassphrase(validPassphraseHash)
                return Promise(value: validPassphraseHash)
            }
        }
        
        //https://stackoverflow.com/questions/30523285/how-do-i-create-an-inline-recursive-closure-in-swift
        // Quick fix for error catch, because it's using Promise and there are so many func(closure) with captured values, there will be alot trouble to make them as seprated funcions. That's a dirty fix, shoud be refactored later all together.
        var catchError:((Error) -> Void)!
        catchError = { error in
            
            guard let lcpClientError = error as? LCPClientError else {
                completion(nil, LcpError.wrap(error))
                return
            }
            
            let askPassphrase = { (reason: LcpPassphraseRequestReason) -> Void in
                firstly {
                    return promptPassphrase(reason: reason)
                }.then { passphraseHash -> Promise<LcpLicense> in
                    return validatePassphrase(passphraseHash: passphraseHash)
                }.then { lcpLicense -> Void in
                    completion(lcpLicense, nil)
                }.catch(policy: CatchPolicy.allErrors, execute:catchError)
            }
            
            switch lcpClientError {
            case .userKeyCheckInvalid:
                askPassphrase(.changedPassphrase)
            case .noValidPassphraseFound:
                askPassphrase(.invalidPassphrase)
            default:
                completion(nil, LcpError.wrap(error))
                return
            }
        }
        
        // get passphrase from DB, if not found prompt user, validate, go on
        firstly {
            // 1/ Validate the license structure (Nothing yet)
            try self.validateLicense()
            }.then { _ in
                // 2/ Get the passphrase associated with the license
                // 2.1/ Check if a passphrase hash has already been stored for the license.
                // 2.2/ Check if one or more passphrase hash associated with
                //      licenses from the same provider have been stored.
                //      + calls the r2-lcp-client library  to validate it.
                try self.passphraseFromDb()
            }.then { passphraseHash -> Promise<String> in
                switch passphraseHash {
                // In case passphrase from db isn't found/valid.
                case nil:
                    // 3/ Display the hint and ask the passphrase to the user.
                    //      + calls the r2-lcp-client library  to validate it.
                    return promptPassphrase()
                // Passphrase from db was already ok.
                default:
                    return Promise(value: passphraseHash!)
                }
            }.then { passphraseHash -> Promise<LcpLicense> in
                return validatePassphrase(passphraseHash: passphraseHash)
            }.then { lcpLicense -> Void in
                completion(lcpLicense, nil)
            }.catch(policy: CatchPolicy.allErrors, execute:catchError)
    }
    
    /// Handle the processing of a publication protected with a LCP DRM.
    ///
    /// - Parameters:
    ///   - publicationPath: The path of the publication.
    ///   - drm: The drm object associated with the Publication.
    ///   - completion: The completion handler.
    /// - Throws: .
    
    @objc func fetchCRL(success: ((String)->Void)? = nil,
                        fail: (() -> Void)? = nil) {
        // Get Certificat Revocation List. from "http://crl.edrlab.telesec.de/rl/EDRLab_CA.crl"
        guard let url = URL(string: "http://crl.edrlab.telesec.de/rl/EDRLab_CA.crl") else {
            //reject(LcpError.crlFetching)
            fail?()
            return
        }
        
        let task = URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
            guard let httpResponse = response as? HTTPURLResponse else {
                if let _ = error {fail?()}
                return
            }
            if error == nil {
                switch httpResponse.statusCode {
                case 200:
                    // update the status document
                    if let data = data {
                        let pem = "-----BEGIN X509 CRL-----\(data.base64EncodedString())-----END X509 CRL-----";
                        success?(pem)
                    }
                default:
                    fail?()
                }
            } else {fail?()}
        })
        task.resume()
    }
    
}
