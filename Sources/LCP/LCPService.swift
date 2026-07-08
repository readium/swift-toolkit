//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Service used to acquire and open publications protected with LCP.
///
/// When a passphrase is not already stored in the `passphraseRepository`, it
/// is requested from the provided `LCPAuthenticating` instance. If
/// `allowUserInteraction` is false then the `authentication` implementation
/// will not present any dialog to the user. This can be the desired behavior
/// when trying to import a license in the background, without prompting the
/// user for their passphrase.
public final class LCPService: Loggable {
    private let licenses: LicensesService
    private let passphrases: PassphrasesService
    private let assetRetriever: AssetRetriever

    /// - Parameters:
    ///   - client: The LCP client used for core license operations.
    ///   - deviceName: Device name used when registering a license to an LSD
    ///     server. We recommend using `UIDevice.current.name` and adding the
    ///     `com.apple.developer.device-information.user-assigned-device-name`
    ///     entitlement.
    ///   - deviceId: Device ID used when registering a license to an LSD
    ///     server. You must ensure the identifier is unique and stable for the
    ///     device (persist and reuse across app launches). If not provided, the
    ///     device ID will be generated as a random UUID.
    ///   - licenseRepository: Repository for managing stored licenses.
    ///   - passphraseRepository: Repository for managing user passphrases.
    ///   - assetRetriever: The retriever used to fetch protected assets.
    ///   - httpClient: The HTTP client used for network requests to LSD/LCP servers.
    public init(
        client: LCPClient,
        deviceName: String,
        deviceId: String? = nil,
        licenseRepository: LCPLicenseRepository,
        passphraseRepository: LCPPassphraseRepository,
        assetRetriever: AssetRetriever,
        httpClient: HTTPClient
    ) {
        let passphrases = PassphrasesService(
            client: client,
            repository: passphraseRepository
        )

        licenses = LicensesService(
            client: client,
            licenses: licenseRepository,
            crl: CRLService(httpClient: httpClient),
            device: DeviceService(
                deviceName: deviceName,
                deviceId: deviceId,
                repository: licenseRepository,
                httpClient: httpClient
            ),
            assetRetriever: assetRetriever,
            httpClient: httpClient,
            passphrases: passphrases
        )

        self.passphrases = passphrases
        self.assetRetriever = assetRetriever
    }

    /// Stores an LCP passphrase candidate in the repository, without
    /// associating it with a specific license. Useful to preload a passphrase
    /// ahead of time.
    ///
    /// - Parameters:
    ///   - passphrase: The passphrase to store.
    ///   - isHashed: Whether `passphrase` is already a SHA-256 hash. If
    ///     `false`, it is hashed before being stored.
    ///   - userID: The user identifier this passphrase is associated with, if
    ///     known.
    ///   - provider: The license provider this passphrase is associated with,
    ///     if known.
    public func addPassphrase(
        _ passphrase: String,
        isHashed: Bool,
        userID: User.ID? = nil,
        provider: LicenseDocument.Provider? = nil
    ) async throws(LCPAddPassphraseError) {
        try await passphrases.addPassphrase(
            passphrase,
            isHashed: isHashed,
            userID: userID,
            provider: provider
        )
    }

    /// Acquires a protected publication from an LCPL.
    public func acquirePublication(
        from lcpl: LicenseDocumentSource,
        onProgress: @escaping @Sendable (LCPProgress) -> Void = { _ in }
    ) async -> Result<LCPAcquiredPublication, LCPError> {
        await wrap {
            try await licenses.acquirePublication(from: lcpl, onProgress: onProgress)
        }
    }

    /// Injects a `licenseDocument` into a publication package at `url`.
    ///
    /// This is useful if you downloaded the publication yourself instead of using `acquirePublication`.
    public func injectLicenseDocument(
        _ license: LicenseDocument,
        in url: FileURL
    ) async -> Result<Void, LCPError> {
        await wrap {
            try await licenses.injectLicenseDocument(license, in: url)
        }
    }

    /// Opens the LCP license of a protected publication, to access its DRM
    /// metadata and decipher its content.
    ///
    /// If the updated license cannot be stored into the `Asset`, you'll get
    /// an exception if the license points to a LSD server that cannot be
    /// reached, for instance because no Internet gateway is available.
    ///
    /// Updated licenses can currently be stored only into `Asset`s whose
    /// source property points to a `file://` URL.
    ///
    /// - Parameters:
    ///   - asset: The asset whose license is to be retrieved.
    ///   - authentication: Used to retrieve the user passphrase if it is not
    ///     already known. The request will be cancelled if no passphrase is
    ///     found in the LCP passphrase storage and in the given
    ///     `authentication`.
    ///   - allowUserInteraction: Indicates whether the user can be prompted
    ///     for their passphrase.
    public func retrieveLicense(
        from asset: Asset,
        authentication: LCPAuthenticating,
        allowUserInteraction: Bool
    ) async -> Result<LCPLicense, LCPError> {
        await wrap {
            try await licenses.retrieve(
                from: asset,
                authentication: authentication,
                allowUserInteraction: allowUserInteraction
            )
        }
    }

    @available(*, unavailable, message: "The `sender` parameter has been removed. Present any UI from your `LCPDialogAuthenticationDelegate` implementation and use the variant without `sender`.")
    public func retrieveLicense(
        from asset: Asset,
        authentication: LCPAuthenticating,
        allowUserInteraction: Bool,
        sender: Any?
    ) async -> Result<LCPLicense, LCPError> {
        fatalError()
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
public enum LicenseDocumentSource: Sendable {
    /// Raw bytes of the LCPL.
    case data(Data)

    /// LCPL or LCP protected package stored on the file system.
    case file(FileURL)

    /// LCPL already parsed to a ``LicenseDocument``.
    case licenseDocument(LicenseDocument)
}
