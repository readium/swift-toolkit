//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

final class LicensesService: Loggable {
    // Mapping between an unprotected format to the matching LCP protected format.
    private let mediaTypesMapping: [MediaType: MediaType] = [
        .readiumAudiobook: .lcpProtectedAudiobook,
        .pdf: .lcpProtectedPDF,
    ]

    private let isProduction: Bool
    private let client: LCPClient
    private let licenses: LCPLicenseRepository
    private let crl: CRLService
    private let device: DeviceService
    private let assetRetriever: AssetRetriever
    private let httpClient: HTTPClient
    private let passphrases: PassphrasesService

    init(
        isProduction: Bool,
        client: LCPClient,
        licenses: LCPLicenseRepository,
        crl: CRLService,
        device: DeviceService,
        assetRetriever: AssetRetriever,
        httpClient: HTTPClient,
        passphrases: PassphrasesService
    ) {
        self.isProduction = isProduction
        self.client = client
        self.licenses = licenses
        self.crl = crl
        self.device = device
        self.assetRetriever = assetRetriever
        self.httpClient = httpClient
        self.passphrases = passphrases
    }

    func retrieve(
        from asset: Asset,
        authentication: LCPAuthenticating?,
        allowUserInteraction: Bool,
        sender: Any?
    ) async throws -> LCPLicense {
        try await retrieve(
            from: makeLicenseContainer(for: asset),
            authentication: authentication,
            allowUserInteraction: allowUserInteraction,
            sender: sender
        )
    }

    private func retrieve(
        from container: LicenseContainer,
        authentication: LCPAuthenticating?,
        allowUserInteraction: Bool,
        sender: Any?
    ) async throws -> License {
        let initialData = try await container.read()

        func onLicenseValidated(of license: LicenseDocument) async throws {
            // Any errors are ignored to avoid blocking the publication.

            do {
                try await licenses.addLicense(license)
            } catch {
                log(.error, "Failed to add the LCP License to the local database: \(error)")
            }

            // Updates the License in the container if needed
            if license.jsonData != initialData {
                do {
                    try await container.write(license)
                    log(.debug, "Wrote updated License Document in container")
                } catch {
                    log(.error, "Failed to write updated License Document in container: \(error)")
                }
            }
        }

        let validation = LicenseValidation(
            authentication: authentication,
            allowUserInteraction: allowUserInteraction,
            sender: sender,
            isProduction: isProduction,
            client: client,
            crl: crl,
            device: device,
            httpClient: httpClient,
            passphrases: passphrases,
            onLicenseValidated: onLicenseValidated
        )

        let documents = try await validation.validate(.license(initialData))

        return License(documents: documents, client: client, validation: validation, licenses: licenses, device: device, httpClient: httpClient)
    }

    func acquirePublication(
        from lcpl: LicenseDocumentSource,
        onProgress: @escaping (LCPProgress) -> Void
    ) async throws -> LCPAcquiredPublication {
        guard let license = try await readLicense(from: lcpl) else {
            throw LCPError.notALicenseDocument(lcpl)
        }

        let url = try license.url(for: .publication)

        onProgress(.percent(0))

        let download = try await httpClient.download(
            url,
            onProgress: { onProgress(.percent(Float($0))) }
        ).get()

        let format = try await injectLicenseAndGetFormat(
            license,
            in: download.location,
            mediaTypeHint: download.mediaType
        )

        return LCPAcquiredPublication(
            localURL: download.location,
            format: format,
            suggestedFilename: format.fileExtension.appendedToFilename(license.id),
            licenseDocument: license
        )
    }

    func injectLicenseDocument(
        _ license: LicenseDocument,
        in url: FileURL
    ) async throws {
        let _ = try await injectLicenseAndGetFormat(license, in: url, mediaTypeHint: nil)
    }

    private func injectLicenseAndGetFormat(
        _ license: LicenseDocument,
        in url: FileURL,
        mediaTypeHint: MediaType? = nil
    ) async throws -> Format {
        var formatHints = FormatHints()
        if let type = license.publicationLink.mediaType {
            formatHints.mediaTypes.append(type)
        }
        if let type = mediaTypeHint {
            formatHints.mediaTypes.append(type)
        }

        let asset = try await assetRetriever.retrieve(url: url, hints: formatHints)
            .mapError { LCPError.licenseContainer(ContainerError.openFailed($0)) }
            .get()

        try await injectLicense(license, in: asset)

        return asset.format
    }

    private func readLicense(from lcpl: LicenseDocumentSource) async throws -> LicenseDocument? {
        switch lcpl {
        case let .data(data):
            return try LicenseDocument(data: data)
        case let .file(file):
            let asset = try await assetRetriever.retrieve(url: file)
                .mapError { LCPError.licenseContainer(ContainerError.openFailed($0)) }
                .get()
            let container = try makeLicenseContainer(for: asset)
            guard try await container.containsLicense() else {
                return nil
            }
            return try await LicenseDocument(data: container.read())
        case let .licenseDocument(license):
            return license
        }
    }

    /// Injects the given License Document into the `file` acquired using `downloadTask`.
    private func injectLicense(_ license: LicenseDocument, in asset: Asset) async throws {
        let container = try makeLicenseContainer(for: asset)
        try await container.write(license)
    }
}
