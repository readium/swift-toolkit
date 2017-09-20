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
    case noStatusDocument
    case licenseDocumentData
    case publicationData

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
        }
    }
}


