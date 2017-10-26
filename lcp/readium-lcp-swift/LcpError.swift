//
//  LcpError.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 9/6/17.
//  Copyright © 2017 Readium. All rights reserved.
//

public enum LcpError: Error {
    case unknown
    case invalidPath
    case invalidLcpl
    case statusLinkNotFound
    case licenseLinkNotFound
    case publicationLinkNotFound
    case hintLinkNotFound
    case registerLinkNotFound
    case noStatusDocument
    case licenseDocumentData
    case publicationData
    case registrationFailure
    case deviceId
    case unexpectedServerError
    case invalidHintData
    case archive
    case fileNotInArchive
    case noPassphraseFound
    case emptyPassphrase
    case invalidJson
    case invalidContext
    case crlFetching

    case licenseStatus
    case invalidRights

    public var localizedDescription: String {
        switch self {
        case .unknown:
            return "Unknown error."
        case .invalidPath:
            return "The provided license file path is incorrect."
        case .invalidLcpl:
            return "The provided license isn't a correctly formatted LCPL file. "
        case .statusLinkNotFound:
            return "The status link is missing from the license document."
        case .licenseLinkNotFound:
            return "The license link is missing from the status document."
        case .publicationLinkNotFound:
            return "The publication link is missing from the license document."
        case .hintLinkNotFound:
            return "The hint link is missing from the license document."
        case .registerLinkNotFound:
            return "The register link is missing from the status document."
        case .noStatusDocument:
            return "Updating the license failed, there is no status document."
        case .licenseDocumentData:
            return "Updating license failed, the fetche data is invalid."
        case .publicationData:
            return "The publication data is invalid."
        case .licenseStatus:
            return "This license is not valid anymore."
        case .invalidRights:
            return "The rights of this license aren't valid."
        case .registrationFailure:
            return "The device could not be registered properly."
        case .deviceId:
            return "Couldn't retrieve/generate a proper deviceId."
        case .unexpectedServerError:
            return "An unexpected error has occured."
        case .invalidHintData:
            return "The data returned by the server for the hint is not valid."
        case .archive:
            return "Coudn't instantiate the archive object."
        case .fileNotInArchive:
            return "The file you requested couldn't be found in the archive."
        case .noPassphraseFound:
            return "Couldn't find a valide passphrase in the database, please provide a passphrase."
        case .emptyPassphrase:
            return "The passphrase provided is empty."
        case .invalidJson:
            return "The JSON license is not valid."
        case .invalidContext:
            return "The context provided is invalid."
        case .crlFetching:
            return "Error while fetching the certificate revocation list"
        }
    }
}


