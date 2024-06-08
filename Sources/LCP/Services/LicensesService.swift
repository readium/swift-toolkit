//
//  Copyright 2024 Readium Foundation. All rights reserved.
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
            from: try makeLicenseContainer(for: asset),
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

        guard let documents = try await validation.validate(.license(initialData)) else {
            throw LCPError.missingPassphrase
        }

        // Check the license status error if there's any
        // Note: Right now we don't want to return a License if it fails the Status check, that's why we attempt to get the DRM context. But it could change if we want to access, for example, the License metadata or perform an LSD interaction, but without being able to decrypt the book. In which case, we could remove this line.
        // Note2: The License already gets in this state when we perform a `return` successfully. We can't decrypt anymore but we still have access to the License Documents and LSD interactions.
        _ = try documents.getContext()

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

        let file = try await injectLicense(license, in: download)
        return LCPAcquiredPublication(
            localURL: file,
            suggestedFilename: suggestedFilename(for: file, license: license),
            licenseDocument: license
        )
    }

    private func readLicense(from lcpl: LicenseDocumentSource) async throws -> LicenseDocument? {
        switch lcpl {
        case .data(let data):
            return try LicenseDocument(data: data)
        case .file(let file):
            let asset = try await assetRetriever.retrieve(url: file)
                .mapError { LCPError.licenseContainer(ContainerError.openFailed($0)) }
                .get()
            let container = try makeLicenseContainer(for: asset)
            guard try await container.containsLicense() else {
                return nil
            }
            return try await LicenseDocument(data: container.read())
        case .licenseDocument(let license):
            return license
        }
    }

    /// Injects the given License Document into the `file` acquired using `downloadTask`.
    private func injectLicense(_ license: LicenseDocument, in download: HTTPDownload) async throws -> FileURL {
        var hints = FormatHints()
        if let type = license.link(for: .publication)?.mediaType {
            hints.mediaTypes.append(type)
        }
        if let type = download.mediaType {
            hints.mediaTypes.append(type)
        }

        let asset = try await assetRetriever.retrieve(url: download.location, hints: hints)
            .mapError { LCPError.licenseContainer(ContainerError.openFailed($0)) }
            .get()

        let container = try makeLicenseContainer(for: asset)
        try await container.write(license)

        return download.location
    }

    /// Returns the suggested filename to be used when importing a publication.
    private func suggestedFilename(for file: FileURL, license: LicenseDocument) -> String {
        let fileExtension: String? = {
            let publicationLink = license.link(for: .publication)
            // FIXME:
//            if var mediaType = MediaType.of(file, mediaType: publicationLink?.type) {
//                mediaType = mediaTypesMapping[mediaType] ?? mediaType
//                return mediaType.fileExtension ?? file.pathExtension
//            } else {
            return file.pathExtension
            // }
        }()
        let suffix = fileExtension?.addingPrefix(".") ?? ""

        return "\(license.id)\(suffix)"
    }
}
