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
    
    public init() {
        let db = Database.shared
        let network = NetworkService()
        passphrases = db.transactions
        licenses = LicensesService(
            licenses: db.licenses,
            crl: CRLService(network: network),
            device: DeviceService(repository: db.licenses, network: network),
            network: network,
            passphrases: PassphrasesService(repository: passphrases)
        )
    }
    
    /// Returns whether the given `file` is protected by LCP.
    public func isLCPProtected(_ file: URL) -> Bool {
        warnIfMainThread()
        return makeLicenseContainerSync(for: file)?.containsLicense() == true
    }
    
    /// Preloads the given `passphrase` to prevent showing the user a passphrase dialog.
    ///
    /// If the passphrase is already hashed, set `hashed` to true.
    ///
    /// This can be used in the context of LCP Automatic Key Retrieval, for example.
    /// https://readium.org/lcp-specs/notes/lcp-key-retrieval.html
    public func addPassphrase(_ passphrase: String, hashed: Bool, for license: LicenseDocument) -> Bool {
        return addPassphrase(passphrase, hashed: hashed, licenseId: license.id, provider: license.provider, userId: license.user.id)
    }
    
    /// Preloads the given `passphrase` to prevent showing the user a passphrase dialog.
    ///
    /// If the passphrase is already hashed, set `hashed` to true.    ///
    ///
    /// This can be used in the context of LCP Automatic Key Retrieval, for example.
    /// https://readium.org/lcp-specs/notes/lcp-key-retrieval.html
    @discardableResult
    public func addPassphrase(_ passphrase: String, hashed: Bool, licenseId: String? = nil, provider: String? = nil, userId: String? = nil) -> Bool {
        warnIfMainThread()
        
        var passphrase = passphrase
        if !hashed {
            passphrase = passphrase.sha256()
        }
        
        return passphrases.addPassphrase(passphrase, forLicenseId: licenseId, provider: provider, userId: userId)
    }
    
    /// Acquires a protected publication from a standalone LCPL file.
    @discardableResult
    public func acquirePublication(from lcpl: URL) -> LCPAcquisition {
        licenses.acquirePublication(from: lcpl)
    }
    
    /// Opens the LCP license of a protected publication, to access its DRM metadata and decipher
    /// its content.
    ///
    /// Returns `nil` if the publication is not protected with LCP.
    ///
    /// - Parameters:
    ///   - authentication: Used to retrieve the user passphrase if it is not already known.
    ///     The request will be cancelled if no passphrase is found on the LCP passphrase storage
    ///     and no instance of `LCPAuthenticating` is provided.
    ///   - allowUserInteraction: Indicates whether the user can be prompted for their passphrase.
    ///   - sender: Free object that can be used by reading apps to give some UX context when
    ///     presenting dialogs with `LCPAuthenticating`.
    public func retrieveLicense(
        from publication: URL,
        authentication: LCPAuthenticating?,
        allowUserInteraction: Bool,
        sender: Any? = nil,
        completion: @escaping (CancellableResult<LCPLicense?, LCPError>) -> Void
    ) -> Void {
        licenses.retrieve(from: publication, authentication: authentication, allowUserInteraction: allowUserInteraction, sender: sender)
            .map { $0 as LCPLicense? }
            .resolve(completion)
    }

    /// Creates a `ContentProtection` instance which can be used with a `Streamer` to unlock
    /// LCP protected publications.
    public func contentProtection(with authentication: LCPAuthenticating) -> ContentProtection {
        LCPContentProtection(service: self, authentication: authentication)
    }

}
