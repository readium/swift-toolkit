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

public protocol LCPAuthenticating {
    
    /// Requests a passphrase to decrypt the given license.
    /// The client app can prompt the user to enter the passphrase, or retrieve it by any other means (eg. web service).
    ///
    /// - Parameter license: Information to show to the user about the license being opened.
    /// - Parameter reason: Reason why the passphrase is requested. It should be used to prompt the user.
    /// - Parameter completion: Used to return the retrieved passphrase. If the user cancelled, send nil. The passphrase may
    ///   be already hashed.
    func requestPassphrase(for license: LCPAuthenticatedLicense, reason: LCPAuthenticationReason, completion: @escaping (String?) -> Void)
    
}

public enum LCPAuthenticationReason {
    /// No matching passphrase was found.
    case passphraseNotFound
    /// The provided passphrase was invalid.
    case invalidPassphrase
}

public struct LCPAuthenticatedLicense {

    /// A hint to be displayed to the User to help them remember the User Passphrase.
    public var hint: String {
        return document.encryption.userKey.textHint
    }
    
    /// Location where a Reading System can redirect a User looking for additional information about the User Passphrase.
    public var hintLink: Link? {
        return document.link(for: .hint)
    }
    
    /// Support resources for the user (either a website, an email or a telephone number).
    public var supportLinks: [Link] {
        return document.links(for: .support)
    }
    
    /// URI of the license provider.
    public var provider: String {
        return document.provider
    }
    
    /// Informations about the user owning the license.
    public var user: User? {
        return document.user
    }

    /// License Document being opened.
    public let document: LicenseDocument

    init(document: LicenseDocument) {
        self.document = document
    }

}
