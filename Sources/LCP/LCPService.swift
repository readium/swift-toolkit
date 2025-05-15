//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UIKit

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
    private let assetRetriever: AssetRetriever

    /// - Parameter deviceName: Device name used when registering a license to an LSD server.
    ///   If not provided, the device name will be the default `UIDevice.current.name`.
    public init(
        client: LCPClient,
        licenseRepository: LCPLicenseRepository,
        passphraseRepository: LCPPassphraseRepository,
        assetRetriever: AssetRetriever,
        httpClient: HTTPClient,
        deviceName: String? = nil
    ) {
        // Determine whether the embedded liblcp.a is in production mode, by attempting to open a production license.
        let isProduction: Bool = {
            guard
                let prodLicenseURL = Bundle.module.url(forResource: "prod-license", withExtension: "lcpl"),
                let prodLicense = try? String(contentsOf: prodLicenseURL, encoding: .utf8)
            else {
                return false
            }
            let passphrase = "7B7602FEF5DEDA10F768818FFACBC60B173DB223B7E66D8B2221EBE2C635EFAD" // "One passphrase"
            return client.findOneValidPassphrase(jsonLicense: prodLicense, hashedPassphrases: [passphrase]) == passphrase
        }()

        licenses = LicensesService(
            isProduction: isProduction,
            client: client,
            licenses: licenseRepository,
            crl: CRLService(httpClient: httpClient),
            device: DeviceService(
                deviceName: deviceName ?? UIDevice.current.name,
                repository: licenseRepository,
                httpClient: httpClient
            ),
            assetRetriever: assetRetriever,
            httpClient: httpClient,
            passphrases: PassphrasesService(
                client: client,
                repository: passphraseRepository
            )
        )

        self.assetRetriever = assetRetriever
    }

    /// Acquires a protected publication from an LCPL.
    public func acquirePublication(
        from lcpl: LicenseDocumentSource,
        onProgress: @escaping (LCPProgress) -> Void = { _ in }
    ) async -> Result<LCPAcquiredPublication, LCPError> {
        await wrap {
            try await licenses.acquirePublication(from: lcpl, onProgress: onProgress)
        }
    }

    /// Opens the LCP license of a protected publication, to access its DRM
    /// metadata and decipher its content.
    ///
    /// If the updated license cannot be stored into the ``Asset``, you'll get
    /// an exception if the license points to a LSD server that cannot be
    /// reached, for instance because no Internet gateway is available.
    ///
    /// Updated licenses can currently be stored only into ``Asset``s whose
    /// source property points to a `file://` URL.
    ///
    /// - Parameters:
    ///   - authentication: Used to retrieve the user passphrase if it is not
    ///     already known. The request will be cancelled if no passphrase is
    ///     found in the LCP passphrase storage and in the given
    ///     `authentication`.
    ///   - allowUserInteraction: Indicates whether the user can be prompted
    ///     for their passphrase.
    ///   - sender: Free object that can be used by reading apps to give some
    ///     UX context when presenting dialogs with ``LCPAuthenticating``.
    public func retrieveLicense(
        from asset: Asset,
        authentication: LCPAuthenticating,
        allowUserInteraction: Bool,
        sender: Any?
    ) async -> Result<LCPLicense, LCPError> {
        await wrap {
            try await licenses.retrieve(
                from: asset,
                authentication: authentication,
                allowUserInteraction: allowUserInteraction,
                sender: sender
            )
        }
    }

    /// Creates a `ContentProtection` instance which can be used with a `Streamer` to unlock
    /// LCP protected publications.
    ///
    /// The provided `authentication` will be used to retrieve the user passphrase when opening an
    /// LCP license. The default implementation `LCPDialogAuthentication` presents a dialog to the
    /// user to enter their passphrase.
    public func contentProtection(with authentication: LCPAuthenticating) -> ContentProtection {
        LCPContentProtection(service: self, authentication: authentication, assetRetriever: assetRetriever)
    }

    private func wrap<Success>(_ block: () async throws -> Success) async -> Result<Success, LCPError> {
        do {
            return try await .success(block())
        } catch {
            return .failure(.wrap(error))
        }
    }
}

/// Source of an LCP License Document (LCPL) file.
public enum LicenseDocumentSource {
    /// Raw bytes of the LCPL.
    case data(Data)

    /// LCPL or LCP protected package stored on the file system.
    case file(FileURL)

    /// LCPL already parsed to a ``LicenseDocument``.
    case licenseDocument(LicenseDocument)
}
