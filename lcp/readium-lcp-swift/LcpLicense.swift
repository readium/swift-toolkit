//
//  LcpLicense.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/11/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

public struct LcpLicense {
    public var uri: URL
    public var licenseDocument: LicenseDocument?
    public var statusDocument: StatusDocument?

    internal init(uri: URL) {
        self.uri = uri
    }

    public func isRevoked() -> Bool {
        guard let statusDocument = statusDocument else {
            return false
        }
        return statusDocument.status != StatusDocument.Status.revoked
    }
}
