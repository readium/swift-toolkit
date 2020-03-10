//
//  Deprecated.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 19.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


@available(*, unavailable, message: "Remove all the code in `handleLcpPublication` and use `LCPLibraryService.loadPublication` instead, in the latest version of r2-testapp-swift")
final public class LcpSession {}


final public class LcpLicense {

    @available(*, unavailable, message: "Replace all the LCP code in `publication(at:)` by `LCPService.importPublication` (see `LCPLibraryService.fulfill` in the latest version)")
    public init(withLicenseDocumentAt url: URL) throws {}
    
    @available(*, deprecated, message: "Removing the LCP license is not needed anymore, delete the LCP-related code in `remove(publication:)`")
    public init(withLicenseDocumentIn url: URL) throws {}
    
    @available(*, deprecated, message: "Removing the LCP license is not needed anymore, delete the LCP-related code in `remove(publication:)`")
    public func removeDataBaseItem() throws {}
    
    @available(*, deprecated, message: "Removing the LCP license is not needed anymore, delete the LCP-related code in `remove(publication:)`")
    public static func removeDataBaseItem(licenseID: String) throws {}

}


@available(*, unavailable, message: "Remove `promptPassphrase` and implement the protocol `LCPAuthenticating` instead (see LCPLibraryService in the latest version)")
public enum LcpError: Error {}
