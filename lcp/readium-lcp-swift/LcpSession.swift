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

internal class LcpSession {
    internal let lcpLicense: LcpLicense
    internal let passphrases: PassphrasesService
    
    init(container: LicenseContainer, passphrases: PassphrasesService) throws {
        self.lcpLicense = try LcpLicense(container: container)
        self.passphrases = passphrases
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
    }
    
    /// Generate a Decipherer for the LCP drm.
    ///
    /// - Parameters:
    ///   - passphrase: The passphrase.
    ///   - completion: The code to be executed on success.
    func resolve(using passphrase: String, pemCrl: String) -> Promise<LcpLicense> {
        return evaluate()
            .then { _ -> LcpLicense in
                return try self.getLcpContext(jsonLicense: self.lcpLicense.license.json,
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
    func getLcpContext(jsonLicense: String, passphrase: String, pemCrl: String) throws -> LcpLicense {
        lcpLicense.context = try createContext(jsonLicense: jsonLicense, hashedPassphrase: passphrase, pemCrl: pemCrl)
        return lcpLicense
    }

    /// <#Description#>
    ///
    /// - Returns: <#return value description#>
    /// - Throws: <#throws value description#>
    func validateLicense() throws -> Promise<Void> {
        // JSON Schema or something // TODO
        return Promise<Void>()
    }
    
    func loadDrm(_ completion: @escaping (Result<LcpLicense>) -> Void) throws
    {
        let kCRLDate = "kCRLDate"
        let kCRLString = "kCRLString"
        
        let updateCRL = { (newCRL:String) -> Void in
            UserDefaults.standard.set(newCRL, forKey: kCRLString)
            UserDefaults.standard.set(Date(), forKey: kCRLDate)
        }
        
        func resolveLicense(passphraseHash: String) -> Promise<LcpLicense> {
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
        
        // request the license's passphrase, validate, go on
        firstly {
            try self.validateLicense()
        }.then { _ in
            wrap { self.passphrases.request(for: self.lcpLicense.license, completion: $0) }
        }.then { passphrase -> Promise<LcpLicense> in
            return resolveLicense(passphraseHash: passphrase)
        }.then { lcpLicense -> Void in
            completion(.success(lcpLicense))
        }.catch { error in
            completion(.failure(LcpError.wrap(error)))
        }
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
