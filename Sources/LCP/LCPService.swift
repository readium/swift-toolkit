//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Service used to acquire and open publications protected with LCP.
///
/// If an `LCPAuthenticating` instance is not given when expected, the request is cancelled if no
/// passphrase is found in the local database. This can be the desired behavior when trying to
/// import a license in the background, without prompting the user for its passphrase.
///
/// You can freely use the `sender` parameter to give some UI context which will be forwarded to
/// your instance of `LCPAuthenticating`. This can be useful to provide the host `UIViewController`
/// when presenting a dialog, for example.
public final class LCPService: Loggable {

    private let licenses: LicensesService
    private let passphrases: PassphrasesRepository
    
    public init(client: LCPClient, httpClient: HTTPClient = DefaultHTTPClient()) {
        // Determine whether the embedded liblcp.a is in production mode, by attempting to open a production license.
        let isProduction: Bool = {
            guard
                let prodLicenseURL = Bundle.module.url(forResource: "prod-license", withExtension: "lcpl"),
                let prodLicense = try? String(contentsOf: prodLicenseURL, encoding: .utf8)
                else {
                return false
            }
            let passphrase = "7B7602FEF5DEDA10F768818FFACBC60B173DB223B7E66D8B2221EBE2C635EFAD"  // "One passphrase"
            return client.findOneValidPassphrase(jsonLicense: prodLicense, hashedPassphrases: [passphrase]) == passphrase
        }()

        let db = Database.shared
        passphrases = db.transactions
        licenses = LicensesService(
            isProduction: isProduction,
            client: client,
            licenses: db.licenses,
            crl: CRLService(httpClient: httpClient),
            device: DeviceService(repository: db.licenses, httpClient: httpClient),
            httpClient: httpClient,
            passphrases: PassphrasesService(client: client, repository: passphrases)
        )
    }

    /// Returns whether the given `file` is protected by LCP.
    public func isLCPProtected(_ file: URL) -> Bool {
        warnIfMainThread()
        return makeLicenseContainerSync(for: file)?.containsLicense() == true
    }
    
    /// Acquires a protected publication from a standalone LCPL file.
    ///
    /// You can cancel the on-going download with `acquisition.cancel()`.
    @discardableResult
    public func acquirePublication(from lcpl: URL, onProgress: @escaping (LCPAcquisition.Progress) -> Void = { _ in }, completion: @escaping (CancellableResult<LCPAcquisition.Publication, LCPError>) -> Void) -> LCPAcquisition {
        licenses.acquirePublication(from: lcpl, onProgress: onProgress, completion: completion)
    }
    
    /// Opens the LCP license of a protected publication, to access its DRM metadata and decipher
    /// its content.
    ///
    /// Returns `nil` if the publication is not protected with LCP.
    ///
    /// - Parameters:
    ///   - authentication: Used to retrieve the user passphrase if it is not already known.
    ///     The request will be cancelled if no passphrase is found in the LCP passphrase storage
    ///     and in the given `authentication`.
    ///   - allowUserInteraction: Indicates whether the user can be prompted for their passphrase.
    ///   - sender: Free object that can be used by reading apps to give some UX context when
    ///     presenting dialogs with `LCPAuthenticating`.
    public func retrieveLicense(
        from publication: URL,
        authentication: LCPAuthenticating = LCPDialogAuthentication(),
        allowUserInteraction: Bool = true,
        sender: Any? = nil,
        completion: @escaping (CancellableResult<LCPLicense?, LCPError>) -> Void
    ) -> Void {
        licenses.retrieve(from: publication, authentication: authentication, allowUserInteraction: allowUserInteraction, sender: sender)
            .map { $0 as LCPLicense? }
            .resolve(completion)
    }

    /// Creates a `ContentProtection` instance which can be used with a `Streamer` to unlock
    /// LCP protected publications.
    ///
    /// The provided `authentication` will be used to retrieve the user passphrase when opening an
    /// LCP license. The default implementation `LCPDialogAuthentication` presents a dialog to the
    /// user to enter their passphrase.
    public func contentProtection(with authentication: LCPAuthenticating = LCPDialogAuthentication()) -> ContentProtection {
        LCPContentProtection(service: self, authentication: authentication)
    }

}
