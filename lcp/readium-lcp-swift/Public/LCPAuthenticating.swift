//
//  LCPAuthenticating.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 08.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Protocol to implement in the client app to request passphrases from the user (or any other means).
public protocol LCPAuthenticating: AnyObject {
    
    func requestPassphrase(for data: LCPAuthenticationData, reason: LCPAuthenticationReason, completion: @escaping (String?) -> Void)
    
}

public enum LCPAuthenticationReason {
    /// No matching passphrase was found.
    case passphraseNotFound
    /// The provided passphrase was invalid.
    case invalidPassphrase
}

public struct LCPAuthenticationData {
    
    public let licenseId: String
    public let userEmail: String?
    public let userName: String?
    public let hint: String
    // FIXME: Expose all links
    public let hintUrl: URL?
    
    init(license: LicenseDocument) {
        self.licenseId = license.id
        self.userEmail = license.user.email
        self.userName = license.user.name
        self.hint = license.encryption.userKey.hint
        self.hintUrl = license.link(withRel: .hint)?.href
    }

}
