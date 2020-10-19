//
//  LCPService.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 08.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared


/// Service used to fulfill and access protected publications.
///
/// If an `LCPAuthenticating` instance is not given when expected, the request is cancelled if no
/// passphrase is found in the local database. This can be the desired behavior when trying to
/// import a license in the background, without prompting the user for its passphrase.
///
/// You can freely use the `sender` parameter to give some UI context which will be forwarded to
/// your instance of `LCPAuthenticating`. This can be useful to provide the host `UIViewController`
/// when presenting a dialog, for example.
public protocol LCPService {

    /// Imports a protected publication from a standalone LCPL file.
    ///
    /// - Returns: The download progress value as an `Observable`, from 0.0 to 1.0.
    @discardableResult
    func importPublication(from lcpl: URL, authentication: LCPAuthenticating?, sender: Any?, completion: @escaping (CancellableResult<LCPImportedPublication, LCPError>) -> Void) -> Observable<DownloadProgress>
    
    /// Opens the LCP license of a protected publication, to access its DRM metadata and decipher
    /// its content.
    ///
    /// Returns `nil` if the publication is not protected with LCP.
    ///
    /// - Parameters:
    ///   - allowUserInteraction: Indicates whether the user can be prompted for their passphrase.
    func retrieveLicense(from publication: URL, authentication: LCPAuthenticating?, allowUserInteraction: Bool, sender: Any?, completion: @escaping (CancellableResult<LCPLicense?, LCPError>) -> Void) -> Void
    
    /// Creates a `ContentProtection` instance which can be used with a `Streamer` to unlock
    /// LCP protected publications.
    func contentProtection(with authentication: LCPAuthenticating) -> ContentProtection

}

public extension LCPService {
    
    @discardableResult
    func importPublication(from lcpl: URL, authentication: LCPAuthenticating?, completion: @escaping (CancellableResult<LCPImportedPublication, LCPError>) -> Void) -> Observable<DownloadProgress> {
        return importPublication(from: lcpl, authentication: authentication, sender: nil, completion: completion)
    }
    
    func retrieveLicense(from publication: URL, authentication: LCPAuthenticating?, completion: @escaping (CancellableResult<LCPLicense?, LCPError>) -> Void) -> Void {
        return retrieveLicense(from: publication, authentication: authentication, allowUserInteraction: true, sender: nil, completion: completion)
    }
    
}


/// Informations about a downloaded publication.
public struct LCPImportedPublication {
    /// Path to the downloaded publication.
    /// You must move this file to the user library's folder.
    public let localURL: URL
    
    /// Download task used to fetch the publication.
    /// Note: this is for legacy purpose, when using R2Shared.DownloadSession.
    public let downloadTask: URLSessionDownloadTask?
    
    /// Filename that should be used for the publication when importing it in the user library.
    public let suggestedFilename: String
}


/// Opened license, used to decipher a protected publication and manage its license.
public protocol LCPLicense: DRMLicense, UserRights {
    
    typealias URLPresenter = (URL, _ dismissed: @escaping () -> Void) -> Void
    
    var license: LicenseDocument { get }
    var status: StatusDocument? { get }
    
    /// Number of remaining characters allowed to be copied by the user.
    /// If nil, there's no limit.
    var charactersToCopyLeft: Int? { get }
    
    /// Number of pages allowed to be printed by the user.
    /// If nil, there's no limit.
    var pagesToPrintLeft: Int? { get }

    /// Can the user renew the loaned publication?
    var canRenewLoan: Bool { get }

    /// The maximum potential date to renew to.
    /// If nil, then the renew date might not be customizable.
    var maxRenewDate: Date? { get }
    
    /// Renews the loan up to a certain date (if possible).
    ///
    /// - Parameter presenting: Used when the renew requires to present an HTML page to the user. The caller is responsible for presenting the URL (for example with SFSafariViewController) and then calling the `dismissed` callback once the website is closed by the user.
    func renewLoan(to end: Date?, present: @escaping URLPresenter, completion: @escaping (LCPError?) -> Void)

    /// Can the user return the loaned publication?
    var canReturnPublication: Bool { get }
    
    /// Returns the publication to its provider.
    func returnPublication(completion: @escaping (LCPError?) -> Void)
    
}


/// LCP service factory.
public func R2MakeLCPService() -> LCPService {
    // Composition root
    let db = Database.shared
    let network = NetworkService()
    let device = DeviceService(repository: db.licenses, network: network)
    let crl = CRLService(network: network)
    let passphrases = PassphrasesService(repository: db.transactions)
    let licenses = LicensesService(licenses: db.licenses, crl: crl, device: device, network: network, passphrases: passphrases)
    
    return licenses
}
